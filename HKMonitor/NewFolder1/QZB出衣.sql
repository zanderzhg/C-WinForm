USE [SUNRISE10_CDB]
GO
/****** Object:  StoredProcedure [dbo].[pc_RackOut]    Script Date: 06/21/2017 14:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pc_RackOut]
@hostname nvarchar(50),			--客户端名称
@lineSrc tinyint,				--出衣的生产线编号
@stidSrc tinyint,				--出衣的工作站编号
@rackcode int,					--衣架代码
@outKind tinyint,				--提交的出衣类型, =0流量检测, =1挂衣工序, =2普通工序出衣, =3质检工序出衣架, =4返工到质检站
@qcRlt tinyint,					--1合格, =2返工, =3废品
@failOrd smallint,				--异常工序
@failCode smallint=0,			--异常代码
@failStr nvarchar(64)=NULL,		--返工格式：5,2,4;7,3,6   表示：工序5返工，疵点2,4；工序7返工，疵点3,6；

@lineOld tinyint OUTPUT,		--出衣的生产线编号
@stidOld tinyint OUTPUT,		--出衣的工作站编号

@lineDes tinyint OUTPUT,		--目标生产线编号
@stidDes tinyint OUTPUT,		--目标工作站编号
@trackDes tinyint OUTPUT,		--目标轨道编号

@stidLnk tinyint OUTPUT,		--链接站编号
@trackLnk tinyint OUTPUT,		--链接轨道编号

@nextOrd smallint OUTPUT,		--下一道工序编号
@canOut tinyint OUTPUT,			--=1 正常出衣架; =0不能出衣
@racksub tinyint OUTPUT,		--=1 stidSrc 衣架数, =,终端不减衣架数, 
@msg nvarchar(100) OUTPUT		--提示信息
--WITH ENCRYPTION
AS
SET NOCOUNT ON;
----------------------初始化----------------------
SELECT
	@lineOld=0, @stidOld=0,
	@lineDes=0, @stidDes=0, @trackDes=1, 
	@stidLnk=0, @trackLnk=0, 
	@nextOrd=0,  @canOut=1, @racksub=0, @msg='';
DECLARE @now datetime,
		@today smalldatetime,
		@lineguidYZ uniqueidentifier,
		@ston NVARCHAR(255),--上架站点
		@lasttime datetime,
		@timediff int,
		@batch int,--批次
		@nowsmall smalldatetime;
SET @now=GETDATE();
SELECT @today=CAST(CONVERT(nvarchar, GETDATE(), 112) AS smalldatetime), @nowsmall=@now;
--------------------------上线功能----------------------
SET @batch=0;
SELECT @lineguidYZ=GUID,@ston=WorkLine+'-'+CAST(@stidSrc AS NVARCHAR) FROM tLine WHERE LineID=@lineSrc
IF(dbo.fg_GetPara(@lineguidYZ, 'partsDrive')=1)		--在tPara表中开启部件流
BEGIN
	DECLARE @storgid uniqueidentifier,
			@binCardguid uniqueidentifier,
			@momguid uniqueidentifier,--制单
			@yzrouteguid uniqueidentifier,--加工方案
			@modcsguid uniqueidentifier,--制单详情
			@ZDSUBID uniqueidentifier,--在线制单
			@MoZdGUID uniqueidentifier,--在线制单
			@MoPar_guid uniqueidentifier,
			@PartName nvarchar(200),
			@SName nvarchar(200),
			@CName nvarchar(400),
			
			@neststid uniqueidentifier,--下一站
			@prestid uniqueidentifier,--上一站
			@Instation bit,
			@STAKIND INT,
			--恒康合并站做普通站用
			@seqguid_hb uniqueidentifier,
			@rout_guid_hb uniqueidentifier,
			@seqno_hb int,
			@stfunc_hb int;
	SELECT @storgid=guid,@STAKIND=seqkind FROM tStation WHERE line_guid=@lineguidYZ AND StationID=@stidSrc
	IF(@STAKIND=1)--挂片站 
	BEGIN
		IF(dbo.fg_GetPara(@lineguidYZ, 'onlineWay')=0)
		BEGIN--条码确定上线
			SELECT TOP 1 @binCardguid=BinCardInf_guid,@MoZdGUID=ZdOnline_guid FROM tBinCardHis WHERE Station_guid=@storgid ORDER BY LastUseTime desc
			SELECT @MoPar_guid=MOM_Guid FROM tMODColorSize WHERE GUID=(SELECT MODCS_Guid FROM tzdonline WHERE GUID=@MoZdGUID)
			SELECT TOP 1 @CName=ColorName,@SName=SizeName, @PartName=GarPart FROM tCutBundCard WHERE CardNo= (SELECT CardNo FROM tBinCardInf WHERE GUID = @binCardguid)
			--制单在刷卡时已经上线 
			--部件guid --空没有部件（制单下没有该部件 暂时不提示 ） 上线所属制单不能用mopar
			SELECT @momguid=GUID FROM TMOM WHERE PartName=@PartName and Mo_guid=@MoPar_guid and isparts=1
			--部件加工方案
			SELECT TOP 1 @yzrouteguid=GUID FROM tRoute where mom_guid=@momguid ORDER BY INSERTTIME DESC
			--部件详情
			SELECT @modcsguid=GUID FROM tMODColorSize WHERE MOM_Guid=@momguid AND ColorName=@CName AND SizeName=@SName
			--在线制单里面没有 导入
			IF NOT EXISTS (SELECT TOP 1 1 FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0)	
			BEGIN
				EXEC pm_on_InportZdD			
				@lineguid = @lineguidYZ, -- int
				@zddid = @modcsguid, -- 制单详情guid
				@routeid = @yzrouteguid, -- uniqueidentifier
				@orgstguid = @storgid,--@stguidDes , -- 上架站点的guid；
				@sortlineguid =null  -- int	
			END
			--切换制单，设置当前上线
			SELECT TOP 1 @ZDSUBID=GUID FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0
			EXEC pm_on_SetOrigin
				@subid =@ZDSUBID,
				@stguid= @storgid,
				@assign =1,
				@current =1
		END
		ELSE IF(dbo.fg_GetPara(@lineguidYZ, 'onlineWay')=1)
		BEGIN--顺序确定上线 bug 暂时
			SELECT TOP 1 @modcsguid=MODCS_Guid FROM tZdOnline with(Nolock) WHERE dbo.fm_SubIsUp(guid)=1 AND dbo.fm_GetStrOrigin1(guid,@storgid)=@ston  ORDER BY InsertTime DESC
			SELECT @MoPar_guid=MOM_Guid FROM tMODColorSize WHERE GUID=@modcsguid
			IF EXISTS(SELECT TOP 1 1 FROM TMOM WHERE GUID=@MoPar_guid AND ISPARTS=1)
				OR EXISTS(SELECT TOP 1 1 FROM TMOM WHERE MO_GUID=@MoPar_guid OR MOPAR_GUID=@MoPar_guid)
			BEGIN
				IF EXISTS(SELECT TOP 1 1 FROM TMOM WHERE GUID=@MoPar_guid AND ISPARTS=1)
				BEGIN
					SELECT @MoPar_guid=Mo_guid FROM TMOM WHERE GUID=@MoPar_guid
				END	
				ELSE BEGIN--重置批次
					UPDATE tMOM SET IsOnline=0 ,batch=isnull(batch,0)+1 WHERE Mo_guid=@MoPar_guid AND isparts=1
				END		
				IF NOT EXISTS(SELECT TOP 1 1 FROM tMOM WHERE isparts=1 and Mo_guid=@MoPar_guid and ISNULL(IsOnline,0)=0 and ISNULL(IsYez,0)=1)
				BEGIN --一次循环结束
					IF(dbo.fg_GetPara(@lineguidYZ, 'ktPC')=1)	
						UPDATE tMOM SET IsOnline=0,batch=isnull(batch,0)+1 WHERE Mo_guid=@MoPar_guid AND isparts=1
					ELSE
						UPDATE tMOM SET IsOnline=0 WHERE Mo_guid=@MoPar_guid AND isparts=1
				END	
				SELECT TOP 1 @batch=ISNULL(batch,0) FROM TMOM WHERE isparts=1 and Mo_guid=@MoPar_guid 		
				SELECT TOP 1 @momguid=GUID FROM TMOM WHERE isparts=1 and Mo_guid=@MoPar_guid and ISNULL(IsOnline,0)=0 and ISNULL(IsYez,0)=1  order by partid
			
				SELECT TOP 1 @lasttime=LastTime FROM tRackInf WITH (NOLOCK) WHERE RackCode=@rackcode^0x5aa5aa55
				SELECT TOP 1 @yzrouteguid=GUID FROM tRoute where mom_guid=@momguid ORDER BY INSERTTIME DESC
				SELECT @modcsguid=GUID FROM tMODColorSize WHERE MOM_Guid=@momguid
				select @timediff=DATEDIFF(second , @lasttime, getdate())
				IF(@timediff > 180 or @timediff is null)--避免重复 切制单
				BEGIN
					IF NOT EXISTS (SELECT TOP 1 1 FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0)	
												BEGIN
					EXEC pm_on_InportZdD			
					@lineguid = @lineguidYZ, -- int
					@zddid = @modcsguid, -- 制单详情guid
					@routeid = @yzrouteguid, -- uniqueidentifier
					@orgstguid = @storgid,--@stguidDes , -- 上架站点的guid；
					@sortlineguid =null  -- int	
				END
					--切换制单，设置当前上线
					SELECT TOP 1 @ZDSUBID=GUID FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0
									EXEC pm_on_SetOrigin
					@subid =@ZDSUBID,
					@stguid= @storgid,
					@assign =1,
					@current =1
					UPDATE  TMOM SET IsOnline=1 WHERE GUID=@momguid 
					--没注册的衣架有坑
					UPDATE tRackInf SET LastTime=GETDATE(),batch=@batch WHERE RackCode=@rackcode^0x5aa5aa55 
				END	
			END
		END
	END

	SELECT TOP 1 @neststid=Station_guid,@prestid=Station_guid_Pre,@Instation=InStation,@rout_guid_hb=Route_guid, @seqno_hb=SeqNo FROM tRackInf WITH (NOLOCK) WHERE RackCode=@rackcode^0x5aa5aa55 
	SELECT TOP 1 @seqguid_hb=guid FROM tSeqAssign WITH (NOLOCK)
		WHERE Route_guid=@rout_guid_hb AND ISNULL(bMerge,0)=0 AND SeqOrder<=(SELECT TOP 1 SeqOrder FROM tSeqAssign WITH (NOLOCK) WHERE Route_guid=@rout_guid_hb AND SeqNo=@seqno_hb)
		ORDER BY SeqOrder DESC;
	SELECT TOP 1 @stfunc_hb=ISNULL(StFunc,0) FROM tStAssign WITH (NOLOCK) WHERE SeqAssign_guid=@seqguid_hb AND Station_guid=@neststid;-- AND StEn=1;
	IF(@STAKIND=7 AND @stfunc_hb=7)--合并站 --
	BEGIN
	IF(@prestid IS NULL OR @prestid<>@storgid)--第一次出衣请求
	BEGIN
		IF(@neststid=@storgid)--避免重复 切制单-- and @Instation=1
		BEGIN
			SELECT TOP 1 @modcsguid=MODCS_Guid FROM tZdOnline with(Nolock) WHERE GUID=(SELECT ZdOnline_guid FROM tRackInf WHERE RackCode=@rackcode^0x5aa5aa55) --dbo.fm_SubIsUp(guid)=1 ORDER BY InsertTime DESC
			SELECT @MoPar_guid=MOM_Guid FROM tMODColorSize WHERE GUID=@modcsguid
							--IF NOT EXISTS (SELECT TOP 1 1 FROM TMOM WHERE GUID=@MoPar_guid AND ISPARTS=1)
		--BEGIN
		--	set @momguid=@MoPar_guid 
		--END
		--ELSE BEGIN 
			SELECT @momguid=MoPar_guid FROM TMOM WHERE GUID=@MoPar_guid AND ISPARTS=1
			IF (@momguid IS NULL )
			BEGIN
				SET @momguid=@MoPar_guid
			END
				SELECT TOP 1 @yzrouteguid=GUID FROM tRoute where mom_guid=@momguid ORDER BY INSERTTIME DESC
							IF(@yzrouteguid IS NULL)
			BEGIN
				SET @momguid=@MoPar_guid
			END
			--END
		IF (@momguid IS NOT NULL)--让合并后的上线
		BEGIN
			SELECT TOP 1 @yzrouteguid=GUID FROM tRoute where mom_guid=@momguid ORDER BY INSERTTIME DESC
			SELECT @modcsguid=GUID FROM tMODColorSize WHERE MOM_Guid=@momguid
			IF NOT EXISTS (SELECT TOP 1 1 FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0)	
			BEGIN
				EXEC pm_on_InportZdD			
				@lineguid = @lineguidYZ, -- int
				@zddid = @modcsguid, -- 制单详情guid
				@routeid = @yzrouteguid, -- uniqueidentifier
				@orgstguid = @storgid,--@stguidDes , -- 上架站点的guid；
				@sortlineguid =null  -- int	
			END
			--切换制单，设置当前上线
			SELECT TOP 1 @ZDSUBID=GUID FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid  AND Line_guid=@lineguidYZ AND SubOver=0
			EXEC pm_on_SetOrigin
				@subid =@ZDSUBID,
				@stguid= @storgid,
				@assign =1,
				@current =1
		END
		END
	END
	END
END
-----------------------站点临时表----------------------
SELECT 
	c.guid						--工作站唯一标识
	,c.Line_guid				--生产线唯一标识
	,b.Host_guid				--客户端唯一标识
	,c.MachineCardID			--衣车卡编号
	,c.Employee_guid			--员工唯一标识
	,c.MachineErrHis_guid		--衣车异常历史信息唯一标识
	,b.WorkShop					--班组
	,b.WorkLine					--生产线
	,c.StationID				--工作站
	,IsFull						--是否满站。0表示未满站；1表示满站
	,IsInEnable					--是否能够入站。0表示不能入站；1表示能入站
	,d.ZdOnline_guid			--线上制单唯一标识
	,e.EmpID					--员工编码
	,c.IsUse					--是否可用。0表示不可用；1表示可用
	,b.SeqVersion				--工序版本
	,NowTime=@now				--当前时间
	,Today=@today				--当前日期
	--
	,IsLed1On					--是否开启灯光（LED）
	,IsRefreshTerm				--是否刷新终端
	,IsRefreshStati				--是否刷新工作站
	,c.SeqKind					--工序类型
	,c.IsJoin					--是否桥接
	,c.RackCnt					--衣架数量
	,c.RackCap					--
	,c.IsAutoOut				--是否为自动出衣。0表示不是；1表示是
	,IsPreMerge=isnull(c.IsPreMerge,0)			--是否是预合并站
	,OutKind=@outKind			--提交的出衣类型, =0流量检测, =1挂衣工序, =2普通工序出衣, =3质检工序出衣架, =4返工到质检站
	,b.IsSorting				--是否分拣。0表示不是；1表示是
	,bEdit=CAST(0 AS bit)		--是否编辑；0表示不可编辑；1表示可以编辑
	INTO #tStSrc
	FROM tHost a WITH (NOLOCK)
	INNER JOIN tLine b WITH (NOLOCK) ON a.guid=b.Host_guid AND b.LineID=@lineSrc
	INNER JOIN tStation c WITH (NOLOCK) ON b.guid=c.Line_guid AND c.StationID=@stidSrc
	LEFT JOIN tOrigin d WITH (NOLOCK) ON c.guid=d.Station_guid AND c.Origin_guid=d.guid
	LEFT JOIN tEmployee e WITH (NOLOCK) ON c.Employee_guid=e.guid
	WHERE a.HostName=@hostname;
IF NOT EXISTS(SELECT TOP 1 1 FROM #tStSrc)		--判断临时表中是否有数据
BEGIN
	DROP TABLE #tStSrc;		--释放临时表#tStSrc
	SET @canOut=0;			--设置该站不能出衣
	SELECT @msg=dbo.fl_FormatStr2(NULL, '[{0}-{1}]号工位不存在或未启用', @lineSrc, @stidSrc);	--给出提示信息
	RETURN;
END	
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
SELECT TOP 1		--获取第一条记录
	guid			--唯一标识
	,ICCode=@rackcode	--衣架代码
	,Chk=((RackCode^CAST(LastTime AS int))-Reserved)	--校验位。将衣架卡号与最后操作数据进行异或，并与保留字段做差，如果返回0，表示未发生异常；否则，表示发生异常
	,NowTime=@now		--当前系统时间
	,Today=@today		--当前日期
	,OldStation_guid=Station_guid	--将当前衣架所在工作站的唯一标识设置旧站的唯一标识（因为如果成功出衣，则当前站就是就站，下一个要去的站是新站）
	,OldTrackID=TrackID		--将当前轨道号设置为旧轨道号
	,OldInStation=InStation			--将当前所在站设置为旧所在站
	--
	,BarCode						--条码
	,BarGuid						--条码唯一标识
	,ZdOnline_guid					--在线制单唯一标识
	,ZdOnline_guid1=ZdOnline_guid	--保存合并前的在线标识
	,Route_guid						--制单方案唯一标识
	,SeqNo							--工序号
	,Station_guid					--工作站唯一标识
	,TrackID=TrackID				--轨道号
	,InStation						--所在工作站
	,BinCardInf_guid				--货卡信息唯一标识
	,BinCardOver					--
	,Station_guid_Src				--当前站唯一标识
	,Station_guid_Pre				--SHANG一站唯一标识
	,QAInf_guid						--质量保证信息唯一标识
	,QCFail							--质量控制是否异常。0表示无异常；1表示有异常
	,Station_guid_Link				--工作站_唯一标识_链接
	,InStationLink					--是否站内质检。0表示不在站内质检；1表示站内质检
	,LastTime						--最后执行时间
	,Reserved						--预留字段
	,NeedReset						--是否需要重置。0表示不需要；1表示需要
	,IsDefective					--是否次品。0表示非次品；1表示是次品
	,IsFinished						--是否完成。0表示未完成；1表示完成
	,InsertTime						--插入时间
	,Line_guid_Now					--当前生产线唯一标识
	,PreSeqNo						--下一道工序号
	,Batch=isnull(batch,0)					--衣架批次  
	,bEdit=CAST(0 AS bit)			--是否可编辑。0表示不可编辑；1表示可以编辑
	INTO #tRackSrc					--衣架信息临时表
	FROM tRackInf WITH (NOLOCK)
	WHERE RackCode=@rackcode^0x5aa5aa55
	ORDER BY InsertTime DESC;


UPDATE #tRackSrc SET OldTrackID=ISNULL(OldTrackID, 1), TrackID=ISNULL(TrackID,1);
---------------------------------------------------------------------------------------
CREATE TABLE #tMsg(			--创建消息临时表
	nid int IDENTITY(1,1) NOT NULL,		--整型唯一标识
	WorkLine nvarchar(50) COLLATE DATABASE_DEFAULT,		--生产线
	StationID tinyint,									--工作站
	Msg nvarchar(100) COLLATE DATABASE_DEFAULT,			--消息内容
	Way nvarchar(100) COLLATE DATABASE_DEFAULT			--解决方式（处理方法）
);

--------------------------------------------------------------------------------------

DECLARE @hostguid uniqueidentifier,		--客户端唯一标识
		@lineguidSrc uniqueidentifier,	--当前出衣生产线唯一标识
		@stguidSrc uniqueidentifier,	--当前出衣工作站唯一标识
		@stkind tinyint,				--工作站类型
		@issorting bit,					--是否分拣。0表示不是；1表示是
		@isjoin bit,		--是否为桥接站。0表示不是；1表示是
		@stguidDes uniqueidentifier,	--目标工作站唯一标识
		@missing bit,					--是否遗失。0表示没有遗失；1表示已经遗失
		@empguid uniqueidentifier,		--员工唯一标识
		@offcode int,					--非本位代码
		@machcode int,					--衣车代码
		@macherrguid uniqueidentifier,	--衣车异常唯一标识
		@subguid uniqueidentifier,		--在线制单唯一标识，数据来自ZdOnline_guid
		@Ispremerge bit,
		@isfull bit,
		@isauto bit;					--是否自动出衣。0表示不自动出衣；1表示自动出衣
		

SELECT @missing=0;		--设置该变量为没有遗失的状态
SELECT TOP 1
	@stguidSrc=guid						--当前出衣工作站唯一标识
	,@lineguidSrc=Line_guid				--当前出衣生产线唯一标识
	,@hostguid=Host_guid				--客户端唯一标识
	,@stkind=SeqKind					--工序类型
	,@isjoin=ISNULL(IsJoin, 0)			--是否桥接；0表示非桥接；1表示桥接
	,@machcode=MachineCardID			--衣车代码
	,@empguid=Employee_guid				--员工唯一标识
	,@macherrguid=MachineErrHis_guid	--衣车异常历史信息唯一标识
	,@subguid=ZdOnline_guid				--在线制单唯一标识
	,@isauto=ISNULL(IsAutoOut, 0)		--是否自动出衣。0表示非自动；1表示自动
	,@issorting=ISNULL(IsSorting, 0)	--是否分拣。0表示不是；1表示是
	,@Ispremerge=ISNULL(IsPreMerge,0)
	FROM #tStSrc;			--当前待出衣工作站临时表
	
select @isfull=isfull from tStation where guid=@stguidSrc
-----------------------------------------------------------------------------

----------------------------衣架信息有关的变量声明和赋值--------------------------------------------------------
DECLARE @rackid uniqueidentifier,		--衣架唯一标识
		@lastuse smalldatetime,			--最后使用时间
		@chk int,						--校验位
		@stguidOld uniqueidentifier,	--旧的工作站唯一标识
		@trackidOld tinyint,			--旧的轨道编号
		@stguidLnk uniqueidentifier,	--桥接站唯一标识
		@bInStation bit,				--是否在站内。0表示不在站内；1表示在站内
		@bInStLink bit,					--是否桥接。0表示不桥接；1表示桥接
		@qainfguid uniqueidentifier,	--质量保证信息唯一标识
		@isfinish bit,					--是否完成。0表示未完成；1表示完成
		@routeguid uniqueidentifier,	--方案唯一标识
		@seqno int;						--工序编号

SELECT @chk=0, @bInStation=0, @bInStLink=0, @isfinish=0;	--设置初值
SELECT TOP 1 @rackid=guid						--设置衣架唯一标识
	, @chk=Chk									--设置校验位
	, @stguidOld=OldStation_guid				--设置旧站唯一标识
	, @bInStation=ISNULL(InStation,0)			--设置是否在站内。如果为空，则设置为0
	, @stguidLnk=Station_guid_Link				--设置桥接站唯一标识
	, @bInStLink=ISNULL(InStationLink, 0)		--设置是否在桥接站内
	, @qainfguid=QAInf_guid						--设置质量保证信息唯一标识
	, @isfinish=ISNULL(IsFinished,0)			--设置是否完成，默认值为未完成
	FROM #tRackSrc;								--从衣架临时表中获取上述信息


------------------------衣架号是否注册，更新最后执行时间-------------------------------------------
IF (@rackid IS NULL)	--如果衣架唯一标识为空，判断该生产线（吊挂）是否允许使用未注册衣架
BEGIN
	IF(dbo.fg_GetPara(@lineguidSrc, 's00000010')=1)		--在tPara表中的参数名称是's00000010'的记录关联tParaLine表中的ParaValue（参数值）
	BEGIN
		SET @rackid=NEWID();		--生产衣架唯一标识
		IF(dbo.fg_GetPara(@lineguidSrc, 'ktPC')=1)	
		BEGIN
		INSERT INTO tRackInf(guid, RackCode, LastTime, Reserved, InsertTime,Batch)		--向衣架信息表中插入一条新纪录
			VALUES(@rackid, @rackcode^0x5aa5aa55, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), @now,ISNULL(@batch,0));
		INSERT INTO tUpdate(TblName, guid, OpCode)		--向更新表中插入待同步上传的衣架信息表记录，其中，OpCode字段1为增加，0为修改，-1为删除
			VALUES('tRackInf', @rackid, 1);
		INSERT INTO #tRackSrc (guid, ICCode, NowTime, Today, LastTime, Reserved, bEdit,Batch)		--向衣架临时表中插入记录
			VALUES(@rackid, @rackcode, @now, @today, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), 0,ISNULL(@batch,0));
		END
		ELSE BEGIN
			INSERT INTO tRackInf(guid, RackCode, LastTime, Reserved, InsertTime,Batch)		--向衣架信息表中插入一条新纪录
				VALUES(@rackid, @rackcode^0x5aa5aa55, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), @now,ISNULL(@batch,0));
			INSERT INTO tUpdate(TblName, guid, OpCode)		--向更新表中插入待同步上传的衣架信息表记录，其中，OpCode字段1为增加，0为修改，-1为删除
				VALUES('tRackInf', @rackid, 1);
			INSERT INTO #tRackSrc (guid, ICCode, NowTime, Today, LastTime, Reserved, bEdit,Batch)		--向衣架临时表中插入记录
				VALUES(@rackid, @rackcode, @now, @today, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), 0,ISNULL(@batch,0));
		END
	END
	ELSE
	BEGIN
		SET @canOut=0;		--设置不能出衣
		INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--向消息临时表中插入记录
			SELECT WorkLine, StationID
				, dbo.fl_FormatStr1(@stguidSrc, '衣架{0}未注册', dbo.fg_ReDimInt(@rackcode))
				,dbo.fl_FormatStr(@stguidSrc, '注册或更换衣架')
				FROM #tStSrc;	--从工作站临时表中获取消息临时表中需要插入的记录
		EXEC pc_ExitRackOut @msg OUTPUT;		--执行退出RackOut时保存数据的存储过程
		RETURN;		--结束本（衣架出衣）存储过程
	END
END
ELSE BEGIN	--衣架唯一标识不为空--更新衣架临时表
	--需求名称：安踏风干站需求
	--修改人：zys
	--修改时间：2015-7-25
	IF(@stkind=6)		--风干站
		UPDATE #tRackSrc SET @lastuse=LastTime, Reserved=@rackcode^0x5aa5aa55^CAST(@nowsmall AS int), NeedReset=0, bEdit=1;		--不更新最后访问时间
	ELSE
		UPDATE #tRackSrc SET @lastuse=LastTime, LastTime=@nowsmall, Reserved=@rackcode^0x5aa5aa55^CAST(@nowsmall AS int), NeedReset=0, bEdit=1;
END

------------------------------------------------------------------------------
----------------------------------出衣类型--------------------------------------
IF(@outKind=0 OR @isjoin=1)		--流量检测
BEGIN	
	SET @missing=1;
END
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-----------------------------------定点传输功能--------------------------------
-------------------------------------------------------------------------------
DECLARE @p2prlt int;	--定义点对点结果信息输出变量
EXEC pc_RackP2P			--定点传输
	@rackcode = @rackcode, -- int
    @missing = @missing, -- tinyint
    @stguidSrc = @stguidSrc, -- uniqueidentifier
    @stguidDes = @stguidDes OUTPUT, -- uniqueidentifier
    @rlt = @p2prlt OUTPUT -- int
-----------------------------------无需定点传输-------------------------------------------
IF(@p2prlt = 0)	--非流量监测站
BEGIN			--提取衣架历史信息表中的部分数据建立衣架历史数据临时表
------------------------------------------------------------------------------------------
    -----------------衣架历史信息临时表-----------------------------------------
	SELECT
		guid			--唯一标识
		,SeqNo			--工序编号
		,MOSeqD_guid	--制单工序明细_唯一标识
		,Station_guid	--工作站_唯一标识
		,Employee_guid	--员工_唯一标识
		,ProcessTime	--处理时间
		,TrackID		--轨道号
		,QcResult		--质量控制结果
		,isQA			--是否为质量保证
		,IsMerge		--是否整合
		,IsSortSeq=CAST(0 AS bit)	--是否是分拣工序
		,Route_guid		--加工方案 --addyz 按站返工
		INTO #tHisSrc	--衣架历史信息临时表
		FROM tRackHis WITH (NOLOCK)
		WHERE RackInf_guid=@rackid;	--衣架唯一标识
	----------------------------------------------------------------------
	IF(@missing=0)	--如果没有遗失（处理衣车故障等）
		BEGIN
		--------------------------------------------------------------------------------------
			----------------------------------------------------------------------------------
			IF ((@stkind=0) OR (@stkind=1)) AND (@isjoin=0) AND (@machcode IS NULL) AND (dbo.fg_GetPara(@lineguidSrc, 'h00000200')=1)
			BEGIN
				SET @canOut=0;	--设置不能出衣
				INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--插入消息表
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '未刷衣车卡, 不能出衣')
						, dbo.fl_FormatStr(@stguidSrc, '请刷衣车卡或取消要求刷衣车卡限制')
						FROM #tStSrc;
				EXEC pc_ExitRackOut @msg OUTPUT;	--执行退出衣架出站的存储过程
				RETURN;
			END
			-----------------------------------------------------------------------------------------

			SELECT TOP 1 @offcode=b.OffStdCode		--选择非本位代码
				FROM tEmpRecent a WITH (NOLOCK), tOffStdToday b WITH (NOLOCK)	--从最近员工活动信息表和非本位记录表
				WHERE a.OffStdToday_guid=b.guid AND a.guid=@empguid;	--通过员工唯一标识和非本位唯一标识进行关
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------
			IF ((@offcode > 0) AND EXISTS(SELECT TOP 1 1 FROM tOffStdCode WITH (NOLOCK) WHERE OffStdCode=@offcode AND (IsWork=0 OR IsWork IS NULL)))	--如果还处于非本位状态
			BEGIN
				IF(dbo.fg_GetPara(@lineguidSrc, 's00004000')=1) AND (@macherrguid IS NULL)	--如果打货卡可以结束非本位并且衣车未故障
				BEGIN
					EXEC pg_RecordEmpOffStd		--记录员工非本位操作
						@stguid = @stguidSrc , -- uniqueidentifier
						@isterm = 0 , -- bit
						@empguid = @empguid , -- uniqueidentifier
						@offcode = 0 , -- int
						@now = @now , -- datetime
						@errguid = NULL -- uniqueidentifier
				END
				ELSE	--如果打货卡不可以结束非本位或者衣车故障
				BEGIN	
					SET @canOut=0;	--设置不能出衣
					INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--插入消息临时表
						SELECT WorkLine, StationID
							, dbo.fl_FormatStr(@stguidSrc, '处于非生产性非本位状态, 不能出衣')
							, dbo.fl_FormatStr(@stguidSrc, '切换到本位或生产性非本位')
							FROM #tStSrc;
					EXEC pc_ExitRackOut @msg OUTPUT;	--执行退出衣架出衣存储过程
					RETURN;
				END
			END
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------		
			IF(@macherrguid IS NOT NULL)	--如果衣车异常唯一标识不为空
			BEGIN
				SET @canOut=0;		--设置不能出衣
				INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)		--插入消息临时表
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '衣车故障, 不能出衣')
						, dbo.fl_FormatStr(@stguidSrc, '请等待衣车维修完成')
						FROM #tStSrc;
				EXEC pc_ExitRackOut @msg OUTPUT;		--执行退出衣架出衣存储过程
				RETURN;
			END
			
			IF(dbo.fg_GetPara(@lineguidSrc, 'OpenAlarmLed')<>0)		--如果报警灯未关闭（0-关闭;1-每站独立显示;2-集中显示）
			BEGIN

				UPDATE #tStSrc SET IsLed1On=0, bEdit=1;		--更新工作站临时表，设置报警灯为关闭；记录可编辑
			END
			
		
			----------------------------------------------------------------------
			IF(dbo.fg_GetPara(@lineguidSrc, 's10001000')=1)
			BEGIN
				IF(@issorting = 1)	--如果是分拣XIAN
				BEGIN
					EXEC pc_SortRackOut		--分拣站出衣存储过程
						@qcRlt = @qcRlt, -- tinyint
						@failStr = @failStr, -- nvarchar(64)
						@canout = @canout OUTPUT; -- tinyint
					EXEC pc_ExitRackOut @msg OUTPUT;
					RETURN;
				END
			END			
		-------------没遗失--------------------------------------------------------------------
		END
		-- ------------------普通站给QC站打返工----------------------------------
	    -- ----------------------------------------------------------------------
	    IF(@outKind=1)		--挂衣工序 和13年相同无可优化地方
		BEGIN
		-- ----------------------------------------------------------------------
			SET @seqno=NULL;	--设置工序号为空
			SELECT TOP 1 @seqno=SeqNo FROM #tHisSrc WHERE QcResult=3 AND Station_guid=@stguidSrc ;
			IF (@isfinish=0) AND (@seqno IS NOT NULL)	--如果未完成并且工序号非空
			BEGIN
				IF(@empguid IS NULL)	--如果员工唯一标识为空
				BEGIN
					SELECT @canOut=0;	--设置不能出衣
					INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--插入消息临时表
						SELECT WorkLine, StationID
							, dbo.fl_FormatStr(@stguidSrc, '站员工未在线')
							, dbo.fl_FormatStr(@stguidSrc, '敦促员工上线')
							FROM #tStSrc;
				END
				ELSE BEGIN
					SELECT TOP 1 @subguid=ZdOnline_guid, @routeguid=Route_guid FROM #tRackSrc;	--从衣架临时表中选择在线制单唯一标识和制单方案唯一标识
					EXEC pc_RackRecordSeqHis	--记录本工序前后相关合并工序的动作
						@subid		= @subguid, -- uniqueidentifier		--在线制单唯一标识
						@routeid	= @routeguid, -- uniqueidentifier	--制单方案唯一标识
						@seqno		= @seqno, -- int	--工序号
						@qcfail		= 0, -- bit		--质检异常，0表示无异常
						@missing	= @missing OUTPUT, -- bit	--是否遗失
						@canOut		= @canOut OUTPUT; -- tinyint	--是否能够出站
					UPDATE #tRackSrc SET Station_guid=NULL, Station_guid_Pre=@stguidSrc, bEdit=1;
				END
			END
			ELSE IF EXISTS(SELECT TOP 1 1 FROM tStation WITH (NOLOCK) WHERE guid=@stguidSrc AND SeqKind=1)	--如果该工作站存在并且工序类型（工作站类型）是挂片站
			BEGIN
				
				IF EXISTS(SELECT TOP 1 1 FROM tZdOnLine a WITH (NOLOCK), #tRackSrc b	--从在线制单表和衣架临时表中查询数据
					WHERE a.guid=@subguid AND a.Route_guid=b.Route_guid AND b.Station_guid_Pre=@stguidSrc)	--通过在线制单唯一标识、制单方案唯一标识、前一站_唯一标识三个字段做为查询条件
				AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0)	--判断衣架历史信息临时表中有数据同时未完成
				BEGIN
					--print '挂在挂片站不出衣时, 只进行一次挂片站的处理';
					SELECT @missing=1;	--设置为遗失
				END
				IF(@missing=0)	--如果非遗失
				BEGIN	
					IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0)	--如果衣架历史信息临时表有数据同时未完成
					BEGIN
						--print '非空衣架';
						IF (dbo.fg_GetPara(@lineguidSrc, 'h00000002')=1)	--如果条件成立，则表示清除从挂片站打出的衣架原有信息
						BEGIN
							--print '配置要求初始化挂衣站衣架';
							EXEC pc_RackSetWaster @kind=2;		--执行存储过程，把指定衣架处理成废品
							--print '按新衣架处理'
							EXEC pc_RackRecordNew @canOut OUTPUT;	--执行存储过程，挂衣站出衣
						END
						ELSE BEGIN  --如果条件不成立，则表示不清除从挂片站打出的衣架原有信息
							--print '配置位要求不初始化挂衣工序的衣架, 视为遗漏衣架';
							SELECT @missing=1;	--设置为遗失
						END
					END
					ELSE BEGIN  --如果衣架历史信息临时表没有数据或者已完成
						--p--rint '挂衣架处理';
						EXEC pc_RackRecordNew @canOut OUTPUT;		--执行存储过程，挂衣站出衣
					END
				END
			END
			ELSE BEGIN
				--print '不存在这样的挂衣站';
				IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0)	--如果衣架历史信息临时表有数据同时未完成
				BEGIN
				--	print '非空衣架, 按遗漏衣架来处理'
					SELECT @missing=1;	--设置为遗失
				END
			END			
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind=2)		--普通工序出衣
		BEGIN
		-- ---------------------风干站需求较13年IF条件加了stkind=6和5-------------------------------------------------		
			IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1)		--在tPara表中开启部件流
			BEGIN
				IF ((@stkind=0) or (@stkind=5) or (@stkind=6)) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc)		--如果工作站类型是0（车缝站），并且衣架历史信息表中有数据，同时该站在衣架临时表中没有记录
						AND NOT EXISTS(SELECT TOP 1 1 FROM #tRackSrc WHERE Station_guid_Pre=@stguidSrc)
				BEGIN
					--print '非空衣架, 车缝站, 衣架未处理过';
					EXEC pc_RackRecordGen @canOut OUTPUT, @missing OUTPUT;		--普通站出衣架
				END	
				ELSE IF(@stkind=7) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc)		--如果工作站类型是0（车缝站），并且衣架历史信息表中有数据，同时该站在衣架临时表中没有记录
					AND NOT EXISTS(SELECT TOP 1 1 FROM #tRackSrc WHERE Station_guid_Pre=@stguidSrc)
				BEGIN
					DECLARE @seqguid1 uniqueidentifier,
							@rout_guid uniqueidentifier,
							@stguid1 uniqueidentifier,
							@seqno1 int,
							@stfunc1 int;
					SELECT TOP 1 @rout_guid=Route_guid, @seqno1=SeqNo, @stguid1=Station_guid FROM #tRackSrc;
					SELECT TOP 1 @seqguid1=guid FROM tSeqAssign WITH (NOLOCK)
						WHERE Route_guid=@rout_guid AND ISNULL(bMerge,0)=0 AND  SeqOrder<=(SELECT TOP 1 SeqOrder FROM tSeqAssign WITH (NOLOCK) WHERE Route_guid=@rout_guid AND SeqNo=@seqno1)
						ORDER BY SeqOrder DESC;
					SELECT TOP 1  @stfunc1=ISNULL(StFunc,0) FROM tStAssign WITH (NOLOCK) WHERE SeqAssign_guid=@seqguid1 AND Station_guid=@stguid1;-- AND StEn=1;
					IF(@stfunc1=7)
						EXEC pc_RackRecordMerge @canOut OUTPUT;--合并站出衣
					ELSE
						EXEC pc_RackRecordGen @canOut OUTPUT, @missing OUTPUT;		--普通站出衣架
				END
				ELSE BEGIN
					SELECT @missing=1;--内循环储备站正常找工序，逻辑放在找站时处理
				END
			END	
			ELSE BEGIN
				IF ((@stkind=0) or (@stkind=5) or (@stkind=6)) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc)		--如果工作站类型是0（车缝站），并且衣架历史信息表中有数据，同时该站在衣架临时表中没有记录
					AND NOT EXISTS(SELECT TOP 1 1 FROM #tRackSrc WHERE Station_guid_Pre=@stguidSrc)
				BEGIN
					--print '非空衣架, 车缝站, 衣架未处理过';
					EXEC pc_RackRecordGen @canOut OUTPUT, @missing OUTPUT;		--普通站出衣架
				END		
				ELSE BEGIN  --如果站类型不是普通站，或者衣架历史信息临时表中没有记录，或者衣架信息临时表有记录
					--print '空衣架，或连续出衣，或非普通站，按遗漏衣架处理';
					SELECT @missing=1;	--设置为遗失（遗漏）
				END
			END
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind=3)		--质检工序出衣架
		BEGIN
		-- ----------------------------------------------------------------------
			--print '质检出衣架，已完成衣架Finished=1也可能要求返工'
			IF(@stkind=0) AND (@qcRlt=3)	--如果站类型是普通站，并且质量控制结果是3（废品）
			BEGIN
				EXEC pc_RackGenToQC_1		--普通站送检, 返到指定工序的工位
					@qcRlt = 3,			--质量控制结果是3（废品）
					@failOrd = @failOrd , -- smallint	--异常序号
					@failCode = @failCode , -- smallint		--异常代码
					@failCodeStr = @failStr, -- NVARCHAR(64)	--异常代码描述
					@canOut = @canOut OUTPUT,		--是否能够出站
					@missing =@missing OUTPUT;		--是否遗失（遗漏）
			END
			ELSE IF(@stkind=2) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@qainfguid IS NULL)	--如果是QC站，并且衣架历史信息临时表中有数据，同时质量保证信息唯一标识为空
			BEGIN
				--PRINT 'QC查货'
				EXEC pc_RackRecordQC @qcRlt, @failOrd, @failCode, @failStr,
					@canOut OUTPUT, @missing OUTPUT;
			END
			ELSE IF(@stkind=4) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0) AND
				EXISTS(SELECT TOP 1 1 FROM tQAInf WITH (NOLOCK) WHERE guid=@qainfguid AND Station_guid_QA=@stguidSrc)
			BEGIN
				--PRINT 'QA查货'
				EXEC pc_RackRecordQA @qcRlt, @failOrd, @failCode, @failStr,
					@canOut OUTPUT, @missing OUTPUT;
			END
			ELSE BEGIN
				--print '上衣工位非质检站, 或连续提交，视遗漏衣架x'
				SET @missing=1;
			END
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind=4)	 		
		BEGIN
		-- ----------------------------------------------------------------------
			-- ------------------普通站给QC站打返工--------------------------
			IF(dbo.fg_GetPara(@lineguidSrc, 'h00000080')=0)
			BEGIN
				SET @canOut=0;	--设置不能出衣
				INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)			--插入消息临时表
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '不允许普通站员工返工衣架')
						, dbo.fl_FormatStr(@stguidSrc, '提醒员工停止返工衣架，或更改参数')
						FROM #tStSrc;
				EXEC pc_ExitRackOut @msg OUTPUT;		--执行退出衣架出衣存储过程
				RETURN;
			END
			-- --------------------------------------------
			--PRINT '普通站送检'
			IF(@isfinish=0)  --已完成衣架不能送检
			BEGIN
				IF (dbo.fg_GetPara(@lineguidSrc, 'h00000100')=1)	--要求返到质检站复查
				BEGIN
					EXEC pc_RackGenToQC_0 @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT;
					IF(@nextOrd=0)
					BEGIN
						SELECT @missing=1;	--送检失败, 则视遗漏衣架
					END
				END
				ELSE BEGIN			--不返工到质减战复查
					EXEC pc_RackGenToQC_1 
						@qcRlt = 2,
						@failOrd = @failOrd , -- smallint
						@failCode = @failCode , -- smallint
						@failCodeStr = @failStr, -- NVARCHAR(64)
						@canOut = @canOut OUTPUT,
						@missing =@missing OUTPUT;			    
					SET @outKind=3;		--让其正常查找下道工序
					UPDATE #tStSrc SET OutKind=3;
				END
			END			
		-- ----------------------------------------------------------------------
		END
		ELSE IF (@outKind=5)
		BEGIN
			SELECT IDENTITY(int,1,1) ID,* INTO #tLineSta from [dbo].[f_splitSTR] (@failStr ,',')
			DECLARE @slCnt int,
					@Lid   int,
					@STDESGUID uniqueidentifier,
					@Sid   int;
			SELECT @slCnt=COUNT(1) FROM #tLineSta
			IF(@slCnt=2)
			BEGIN
				SELECT TOP 1 @Lid=CAST (LGUID AS INT) FROM #tLineSta WHERE ID=1
				SELECT TOP 1 @Sid=CAST (LGUID AS INT) FROM #tLineSta WHERE ID=2
				SELECT TOP 1 @STDESGUID=A.guid FROM TSTATION A INNER JOIN TLINE B ON A.LINE_GUID=B.GUID 
					WHERE A.STATIONID=@Sid AND B.LINEID=@Lid
				IF( @STDESGUID  IS NOT NULL)
				BEGIN
					SET @stguidDes =@STDESGUID;
					IF EXISTS (SELECT TOP 1 1 FROM tPTP_qzb WHERE Rack_guid=@rackid)
						UPDATE tPTP_qzb SET staSrc_guid=@stguidSrc,staDes_guid=@stguidDes,L=@Lid,S=@Sid,[str]=@failStr,[DateTime]=GETDATE()
							WHERE Rack_guid=@rackid
					ELSE 
						INSERT INTO tPTP_qzb([GUID],[RackCode],[Rack_guid],[staSrc_guid],[staDes_guid],[L],[S],[str] ,[DateTime])
							VALUES(NEWID(),@rackcode,@rackid,@stguidSrc,@stguidDes,@Lid,@Sid,@failStr,GETDATE())
					UPDATE #tRackSrc SET Station_guid=@stguidDes,bEdit=1;
				END
				ELSE BEGIN
					SELECT @canOut=0;
						INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
						SELECT WorkLine, StationID
							, dbo.fl_FormatStr2(@stguidSrc, 'PTP:[{0}-{1}]号工位不存在',@Lid,@Sid)
							, dbo.fl_FormatStr(@stguidSrc, '请重新输入 线号,站号')
							FROM #tStSrc;
				END
			
			END
			ELSE BEGIN
				SELECT @canOut=0;
					INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, 'PTP: 目标线-站输入格式不对')
						, dbo.fl_FormatStr(@stguidSrc, '请重新输入 线号,站号')
						FROM #tStSrc;
			END
			DROP TABLE #tLineSta
		END
		--------------------------------------(出衣类型分别走完)------------------
		IF(@missing=1)		--如果遗失（遗漏）
		BEGIN
		-- ----------------------------------------------------------------------		
			IF EXISTS(SELECT TOP 1 1 FROM tPTP_qzb WHERE Rack_guid=@rackid)
			BEGIN  --PRP 人为干预
				DECLARE @PTPGUID uniqueidentifier;
				SELECT TOP 1 @stguidDes= staDes_guid,@PTPGUID=GUID FROM tPTP_qzb WHERE Rack_guid=@rackid
				--IF(@stguidOld<>@stguidDes)
				--	DELETE FROM  tPTP_qzb WHERE GUID=@PTPGUID
				--ELSE
				UPDATE #tRackSrc SET Station_guid=@stguidDes,bEdit=1;
			END
			--print '处理遗漏衣架'
			ELSE BEGIN
				SET @qainfguid=NULL;	--质量保证信息唯一标识
				SELECT TOP 1 @routeguid=Route_guid, @seqno=SeqNo, @stguidDes=Station_guid, @trackDes=TrackID	--选择制单方案唯一标识、工序号、目标工作站唯一标识、目标轨道唯一标识、质量保证信息唯一标识
					,@qainfguid=QAInf_guid
					FROM #tRackSrc;		--从衣架信息临时表中			
				IF EXISTS(SELECT TOP 1 1 FROM tSeqAssign  WITH (NOLOCK) WHERE SeqNo=@seqno AND Route_guid=@routeguid )	--如果工序安排表中存在该制单方案和工序号信息对应的记录
				BEGIN
					--print '原来分配的工序仍存在';
				-------------------------------------------------------------------------------
					IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc WHERE ISNULL(QcResult,0)<4 AND SeqNo=@seqno AND Route_guid=@routeguid)	--根据工序号和质量控制结果做为查询条件，能够查询到记录
					BEGIN
						--print '原分配工序已加工过, 正常查找下道工序'
						EXEC pc_RackSearchNextSeq 
								@stguidDes OUTPUT, 
								@trackDes OUTPUT, 
								@nextOrd OUTPUT;
					END
					ELSE IF(@qainfguid IS NOT NULL)----QA检查过了
					BEGIN			
						--print '有质量保证, 正常查找下道工序'
						EXEC pc_RackSearchNextSeq 
								@stguidDes OUTPUT, 
								@trackDes OUTPUT, 
								@nextOrd OUTPUT;
					END
					ELSE BEGIN
						--print '原来分配的工序未加工过'
						---------------找下到工序 WHERE条件可优化-------------------------
						--IF (dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1 AND @seqno IS NOT NULL  AND @stguidDes IS NOT NULL AND @trackDes IS NOT NULL)	--AND @seqno IS  NULL
						--BEGIN
						--	EXEC pc_RackSearchStation 
						--			@routeguid,
						--			@seqno,
						--			@stguidDes OUTPUT,
						--			@trackDes OUTPUT;
						--	UPDATE #tRackSrc SET Station_guid=@stguidDes, bEdit=1;
						--END	
						SELECT @nextOrd=dbo.fm_GetSeqOrder(@routeguid, @seqno);
						DECLARE @seqguid uniqueidentifier;
						SELECT TOP 1 @seqguid=guid FROM tSeqAssign WITH (NOLOCK)
							WHERE Route_guid=@routeguid AND ISNULL(bMerge,0)=0
							AND SeqOrder<=(SELECT TOP 1 SeqOrder FROM tSeqAssign WITH (NOLOCK) WHERE Route_guid=@routeguid AND SeqNo=@seqno)
							ORDER BY SeqOrder DESC;
						-----------------------------------------------------------------
						IF NOT EXISTS(SELECT TOP 1 1 FROM tStAssign WITH (NOLOCK) WHERE SeqAssign_guid=@seqguid AND Station_guid=@stguidDes AND StEn=1 AND (ISNULL(StFunc,0) IN (0,2,3)))
							OR NOT EXISTS(SELECT TOP 1 1 FROM tStation WITH (NOLOCK) WHERE guid=@stguidDes AND RackCnt<RackCap AND IsInEnable=1)
							OR EXISTS(SELECT TOP 1 1 FROM tStation WITH (NOLOCK) WHERE guid=@stguidDes AND SEQKIND=8)  --ADDYZ 原先分配的的站点是内循环储备站
							--OR (@Ispremerge=1 AND dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1)  --yz 预合并功能
							OR EXISTS(SELECT TOP 1 1 FROM tStAssign WITH (NOLOCK) WHERE SeqAssign_guid=@seqguid AND StEn=1 AND (ISNULL(StFunc,0)=7)) --分配工序下有合并站 直接找站
						BEGIN
							--print '原来分配的工位不存在或停止进衣';
							IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc)
							BEGIN
								--print '衣架加工过，重新查找工位';
								EXEC pc_RackSearchStation 
									@routeguid,
									@seqno,
									@stguidDes OUTPUT,
									@trackDes OUTPUT;
								UPDATE #tRackSrc SET Station_guid=@stguidDes, bEdit=1;
							END
							ELSE BEGIN
								--print '衣架还未加工过，分配的挂衣站不存在，重新分配挂片站';
								--DELETE FROM tRackFailHis WHERE RackInf_guid=@rackid;
								--UPDATE #tRackSrc SET BarCode=NULL, BarGuid=NULL, ZdOnline_guid=NULL, Route_guid=NULL, SeqNo=NULL, Station_guid=NULL, TrackID=0, IsDefective=0, bEdit=1;
								EXEC pc_RackSearchNextSeq @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT		--工序号
							END
						END
					END			
					-------------------------------------------------------------------------------
				END			
				ELSE BEGIN
					-------------------------------------------------------------------------------
						----print '原来分配的工序不存在';
					--IF (dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1  AND @stguidDes IS NOT NULL AND @trackDes IS NOT NULL)	--AND @seqno IS  NULL
					--BEGIN
					--	PRINT('防止流量检测重置')
					--END	
					--ELSE BEGIN	
							EXEC pc_RackSearchNextSeq @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT		--工序号	
					--END
					-------------------------------------------------------------------------------
				END				
			END
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind<>4 OR @outKind<>5)	--出站类型不是4-返工到质检站
		BEGIN
			--print '正常查找下道工序'
			EXEC pc_RackSearchNextSeq @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT;
		END		
------------------------------------------------------------------------------------------
END
--------------------------定点传输和非定点传输都要走--------------------------------------
------------------------------------------------------------------------------------------
----------------------------------工序安排、站安排、||增加一个开始请求时间 用来下一个站不能进站时的排队
DECLARE @seqassguid uniqueidentifier,
		@stassguid uniqueidentifier,
		@thisbegtime datetime;
SELECT TOP 1 @seqassguid=b.guid, @stassguid=c.guid, @thisbegtime=c.BeginReqTime
	FROM #tRackSrc a, tSeqAssign b WITH(NOLOCK), tStAssign c WITH(NOLOCK)
	WHERE a.Route_guid=b.Route_guid AND a.PreSeqNo=b.Seqno AND b.guid=c.SeqAssign_guid AND c.Station_guid=@stguidSrc;

------------------------------------排队出站-------------------------------------------
IF (@stguidDes IS NULL) AND (@outkind<>0) AND (@canOut=1) AND (@stkind<>4) AND (@stkind<>7) AND (@stkind<>8) AND(@trackDes<>5) AND (@isjoin=0)
 AND ((dbo.fg_GetPara(@lineguidSrc, 'h00000010')=1) OR (@isauto=1))
BEGIN
-------------------------------需要排队等出站-------------------------------------------
	SELECT @canOut=0;
	UPDATE tStAssign SET BeginReqTime=CASE WHEN BeginReqTime IS NULL THEN @now ELSE BeginReqTime END,LastReqTime=@now WHERE guid=@stassguid;
	-----------------------------------------------------------------------------------
	---------------------后道分拣需要优化（参数控制），不然会造成排队等候出站时排队时间变长----（查询了数据超多的表）
	-----------------------------------------------------------------------------------
	IF(dbo.fg_GetPara(@lineguidSrc, 's10001000')=1)
	BEGIN
		IF NOT EXISTS(SELECT TOP 1 1 FROM #tMsg)
		BEGIN
			--需求名称：后道分拣信息提示需求
			--修改时间：20150605   2016
			--修改人：zys    yz
			DECLARE @SeqKind_Des_Msg int;	--目标站类型
			SELECT @SeqKind_Des_Msg=SeqKind FROM tStation WHERE guid=@stguidDes;
			IF(@stkind=2)
				BEGIN
					DECLARE @CardNo_Fab_Msg int;	--匹卡卡号
					DECLARE @Fab_MoNo_Msg nvarchar(50);	--制单号
					DECLARE @CardNo_Fab_Small_Msg int;	--小卡卡号
					DECLARE @FabNo_Msg nvarchar(50);	--匹号
					--获取小卡卡号
					SELECT @CardNo_Fab_Small_Msg=tCutBundCard.CardNo,@Fab_MoNo_Msg=tCutBundCard.MONo 
						FROM tRackInf  WITH(NOLOCK) left join tBinCardInf WITH(NOLOCK) ON tRackInf.BinCardInf_guid=tBinCardInf.guid
						left join tCutBundCard WITH(NOLOCK) ON tBinCardInf.CardNo=tCutBundCard.CardNo
						WHERE RackCode=@rackcode^0x5aa5aa55
						ORDER BY tRackInf.InsertTime DESC;					--根据衣架信息表的插入时间倒序排列，取最新的记录
					--获取该小卡对应的匹卡的卡号
					SELECT @CardNo_Fab_Msg=b.CardNo FROM tCutBundCard b WITH(NOLOCK), (SELECT MONo,CutLotNo,GarPart,OrderNoFabColor from tCutBundCard WITH(NOLOCK) where CardNo=@CardNo_Fab_Small_Msg and MONo=@Fab_MoNo_Msg) a 
						WHERE b.MONo=a.mono and b.CutLotNo=a.CutLotNo and b.GarPart=a.GarPart and b.OrderNoFabColor=a.OrderNoFabColor AND b.CardType=6
					--获取该匹卡的匹号信息
					SELECT TOP 1 @FabNo_Msg=FabNo from tCutBundCard WITH(NOLOCK) where CardNo=@CardNo_Fab_Msg and MONo=@Fab_MoNo_Msg order by InsertTime desc;
					
					IF (@FabNo_Msg is not null)	--判断待进站的衣架对应的匹卡是否存在
						BEGIN
							INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
							SELECT WorkLine, StationID
								, dbo.fl_FormatStr(@stguidSrc, '找不到工位或满站,分拣站刷匹号'+cast(@FabNo_Msg as varchar(10))+ '的匹卡或出衣')
								, dbo.fl_FormatStr(@stguidSrc, '')
								FROM #tStSrc;
						END
					ELSE BEGIN
							INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
								SELECT WorkLine, StationID
								, dbo.fl_FormatStr(@stguidSrc, '分拣工序找不到工位或满站')
								, dbo.fl_FormatStr(@stguidSrc, '分拣站刷匹卡或打出站内衣架')
								FROM #tStSrc;
						END					
				END
				--ELSE BEGIN
				--INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
				--	SELECT WorkLine, StationID
				--		, dbo.fl_FormatStr(@stguidSrc, '下工序找不到工位, 或满站, 或须分色码')
				--		, dbo.fl_FormatStr(@stguidSrc, '检查下道工序的工位分配情况或更改出衣配置')
				--		FROM #tStSrc;
				--END					
		END
	END	
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '下工序找不到工位, 或满站, 或须分色码')
						, dbo.fl_FormatStr(@stguidSrc, '检查下道工序的工位分配情况或更改出衣配置')
						FROM #tStSrc;
	-----------------------------------------------------------------------------------
END
ELSE BEGIN
-------------------------------不需要排队等出站----------------------------------------
	UPDATE tStAssign SET LastReqTime=@now WHERE guid=@stassguid AND BeginReqTime IS NOT NULL;
END

--
IF (@stguidDes IS NULL) AND (@outkind<>0) AND (@canOut=1)  AND  (@stkind=8)AND (@isjoin=0) and(@isfull=0)
BEGIN
	SELECT @canOut=0;
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '储备站没有所需部件 暂停出衣')
						, dbo.fl_FormatStr(@stguidSrc, '请等待')
						FROM #tStSrc;
END
IF(@nextOrd=-1 AND @stkind=7)
BEGIN --在主轨上转
	SELECT @canOut=0;
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '合并站只允许提前出一个小号部件')
						, dbo.fl_FormatStr(@stguidSrc, '请等待')
						FROM #tStSrc;
END
IF(@trackDes=5)
BEGIN --在主轨上转
	SET @trackDes=1 
	SET @canOut=1;
END

-------------------------------排队----------------------------------------
IF(@canOut=1) AND (@outkind<>0)
BEGIN
	--PRINT '允许出站时，判断是否有同工序其他衣架在排队等待出站'
	IF EXISTS(SELECT TOP 1 1 FROM tStAssign WITH(NOLOCK)
			WHERE SeqAssign_guid=@seqassguid AND BeginReqTime<@thisbegtime AND DATEDIFF(ss, LastReqTime, @now)<15 )
	BEGIN
		SET @canOut=0;
		UPDATE #tRackSrc SET Station_guid=NULL, @stguidDes=NULL, bEdit=1;
		IF NOT EXISTS(SELECT TOP 1 1 FROM #tMsg)
		BEGIN
			INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
				SELECT WorkLine, StationID
					, dbo.fl_FormatStr(@stguidSrc, '同工序衣架排队出站')
					, dbo.fl_FormatStr(@stguidSrc, '同工序衣架排队出站')
					FROM #tStSrc;
		END
	END
END
---------------------------------------------------------------------------------------
DECLARE @bSumRack bit;---1衣架数－1；
SELECT TOP 1 @lineOld=LineID, @stidOld=StationID, @bSumRack=(CASE WHEN a.SumRackTime>@lastuse THEN 0 ELSE 1 END)---@lastuse衣架最后执行时间，SumRackTime线上衣架
	FROM tLine a WITH (NOLOCK), tStation b WITH (NOLOCK)
	WHERE a.guid=b.Line_guid AND b.guid=@stguidOld;
------------------------不能出衣的不能让它在站内卡住后面的衣架------------------------------------------------
IF(@canOut=0)
BEGIN
	--PRINT '不允许出站'
	IF(@bInStation=1)
	BEGIN
		DECLARE @stguidNew uniqueidentifier;
		SELECT TOP 1 @stguidNew=Station_guid FROM #tRackSrc;
		IF (@stguidOld IS NULL AND @stguidNew IS NOT NULL) 
			OR (@stguidOld IS NOT NULL AND @stguidNew IS NULL) 
			OR (@stguidOld<>@stguidNew)
		BEGIN
			--PRINT '前次分配的站点与本次分配的站点不同，则更新原来的站内衣数'
			UPDATE #tRackSrc SET InStation=0, bEdit=1;
			--print '衣架原来是在站内的，并且成功出衣，则更新原来分配的工位站内衣数'
			IF (@bSumRack=1)
			BEGIN
				PRINT 'rackcnt-1'
				IF(@stguidOld=@stguidSrc)
				BEGIN
					--PRINT '当前站点是原来分配的站点'
					UPDATE #tStSrc SET RackCnt=RackCnt-1, IsRefreshTerm=1, bEdit=1
						WHERE RackCnt>0;
					SELECT @racksub=1;
				END
				ELSE
				BEGIN
					UPDATE tStation SET RackCnt=RackCnt-1, IsRefreshTerm=1
						WHERE   RackCnt>0 AND guid=@stguidOld;
					INSERT tUpdate(TblName, guid, OpCode, ColNameStr) 
						VALUES('tStation', @stguidOld, 0, 'RackCnt');
				END
			END
		END
	END
	EXEC pc_ExitRackOut @msg OUTPUT;
	RETURN;
END
------------------------------------------------------------------------------------
--出站后清除衣架排队信息
UPDATE tStAssign SET BeginReqTime=NULL, LastReqTime=NULL WHERE guid=@stassguid;
------------------------------------------------------------------------------------
IF(@missing=0)	--该衣架非遗失（遗漏）
BEGIN
	--PRINT '正常从站点出去，更新产量信息'
	UPDATE #tStSrc SET IsRefreshTerm=1, IsRefreshStati=1, bEdit=1;
END
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
--PRINT '允许出衣'
IF(@bInStation=1)
BEGIN
	--------------------------在站内------------------------------------------------
	UPDATE #tRackSrc SET InStation=0, bEdit=1;
	--print '衣架原来是在站内的，并且成功出衣，则更新原来分配的工位站内衣数'
	IF (@bSumRack=1)
	BEGIN
		--PRINT 'stationold rackcnt-1'
		IF(@stguidOld=@stguidSrc)
		BEGIN
			UPDATE #tStSrc SET RackCnt=RackCnt-1, IsRefreshTerm=1, bEdit=1
				WHERE RackCnt>0;
			--PRINT '提交信息的站点衣数减1'
			SELECT @racksub=1;
		END
		ELSE
		BEGIN
			UPDATE tStation SET RackCnt=RackCnt-1, IsRefreshTerm=1 
				WHERE   RackCnt>0 AND guid=@stguidOld;
			INSERT tUpdate(TblName, guid, OpCode, ColNameStr) 
				VALUES('tStation', @stguidOld, 0, 'RackCnt');
		END
	END
END

IF(@bInStLink=1)
BEGIN
	--------------------------在连接站内------------------------------------------------
	UPDATE #tRackSrc SET InStationLink=0, bEdit=1;
	UPDATE tStation SET RackCnt=RackCnt-1, IsRefreshTerm=1 WHERE guid=@stguidLnk AND RackCnt>0;
	INSERT tUpdate(TblName, guid, OpCode)
		SELECT 'tStation', @stguidLnk, 0;
END

IF(@outKind<>0)
BEGIN
	--PRINT '流量检测时不控制自动出衣'
	EXEC pc_ReserevdStationAutoOut;
END
-----------------------给予目标线和站---------------------------------------
SELECT @stguidLnk=NULL, @trackLnk=0;
DECLARE @lineguidDes uniqueidentifier;
SELECT @lineDes=b.LineID, @stidDes=a.StationID, @lineguidDes=a.Line_guid
	FROM tStation a WITH (NOLOCK), tLine b WITH (NOLOCK)
	WHERE a.guid=@stguidDes AND a.Line_guid=b.guid;
------------------------------------------------------------------------------	
--print '检测是否需要链接站'
IF(@lineguidSrc<>@lineguidDes)
BEGIN
	--print '检测是否需要链接站'
	--PRINT '找桥接站'
	EXEC pc_GetBridgeSt 
	    @lineguidSrc = @lineguidSrc , -- uniqueidentifier
	    @lineguidDes = @lineguidDes , -- uniqueidentifier
	    @stguidSrc=@stguidSrc,--YZ 2017 多次桥接的问题
	    @stguidLnk = @stguidLnk OUTPUT, -- uniqueidentifier
		@trackLnk = @trackLnk OUTPUT;
	IF(@stguidLnk IS NULL)
	BEGIN
		EXEC pc_RecordAlertInf
			@stguid = @stguidSrc
			,@alert =N'衣架不能到达目标点'
			,@solution = N'检查流水线链接配置';
	END
	IF(@stguidLnk=@stguidSrc) AND (@outkind<>0)
	BEGIN
		--PRINT '桥接站同时作车缝站'
		SET @stguidLnk = NULL;
	END
	ELSE
		SELECT TOP 1 @stidLnk=StationID FROM tStation WITH (NOLOCK) WHERE guid=@stguidLnk;
END
--------------------------------------------------------------------------------------
UPDATE #tRackSrc SET Station_guid_Link=@stguidLnk, InStationLink=0,TrackID=@trackDes, bEdit=1;
--------------------------------------------------------------------------------------
EXEC pc_ExitRackOut @msg OUTPUT;