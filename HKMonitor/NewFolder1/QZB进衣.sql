USE [SUNRISE10_CDB]
GO
/****** Object:  StoredProcedure [dbo].[pc_RackIn]    Script Date: 06/22/2017 10:14:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pc_RackIn]
@hostname NVARCHAR(50),		--客户端名称（主机名称）
@lineid tinyint,			--生产线编号
@stid tinyint,				--目标工作站编号
@trackid tinyint=0,			--轨道号
@rackcode int				--衣架号
--WITH ENCRYPTION
AS
SET NOCOUNT ON;
DECLARE @stguid uniqueidentifier;	--目标工作站唯一标识
DECLARE @SeqKind tinyint;--存储工作站类型
SELECT TOP 1 @stguid=c.guid,@SeqKind=c.SeqKind			--获取工作站唯一标识
	FROM tHost a WITH (NOLOCK), tLine b WITH (NOLOCK), tStation c WITH (NOLOCK)		--从主机信息表，生产线信息表，工作站信息表中
	WHERE a.HostName=@hostname AND a.guid=b.Host_guid AND b.LineID=@lineid AND b.guid=c.Line_guid AND c.StationID=@stid;	--条件是主机名，主机唯一标识，生产线号，生产线唯一标识，工作站编号

DECLARE @now datetime,		--当前时间
		@lastuse smalldatetime,				--最后使用时间
		@instation bit, @instlink bit;		--是否在站内，是否是桥接站
SELECT @now=GETDATE();		--为当前时间赋值
SELECT @lastuse=@now, @instation=0, @instlink=0;	--为最后使用时间赋值，设置是否在站内（0-不在），设置是否是桥接站（0-不是）
DECLARE @rackid uniqueidentifier, @stguidreg uniqueidentifier, @stguidlnk uniqueidentifier;	--定义衣架唯一标识，目标工作站唯一标识，桥接站唯一标识
SELECT TOP 1 @rackid=guid, @stguidreg=Station_guid, @instation=ISNULL(InStation, 0)		--设置衣架唯一标识、目标站唯一标识，是否在站内（如果是空，则设置为0-不在站内）
	, @stguidlnk=Station_guid_Link, @instlink=ISNULL(InStationLink, 0)		--桥接站唯一标识，是否在桥接站内（如果是空，则设置为0-不在站内）
	FROM tRackInf WITH (NOLOCK)		--从衣架信息表中
	WHERE RackCode=@rackcode^0x5aa5aa55;		--通过入站读卡器读到的衣架号进行异或之后做为查询条件

DECLARE @ptprackguid uniqueidentifier;		--站到站衣架唯一标识
SELECT @ptprackguid=guid FROM tPTPRack WITH (NOLOCK) WHERE RackCode=@rackcode;	--？从站到站衣架信息表中，以衣架号进行异或之后的结果做为查询条件，获取站到站衣架信息表的唯一标识
IF(@ptprackguid IS NOT NULL)	--如果站到站衣架唯一标识不为空
BEGIN
	UPDATE tPTPRack SET Station_guid=@stguid WHERE guid=@ptprackguid;	--更新站到站衣架信息表，设置工作站唯一标识，以站到站衣架唯一标识做为条件
	INSERT INTO tUpdate(TblName, guid, OpCode)		--插入更新表（表名，唯一标识，操作代码）
		SELECT 'tPTPRack', @ptprackguid, 0;		--选择站到站衣架表名，站到站衣架唯一标识，操作代码设置为0
END
--乔治白PTP
IF EXISTS (SELECT TOP 1 1 FROM tPTP_qzb WHERE Rack_guid=@rackid AND staDes_guid=@stguid)
	DELETE FROM tPTP_qzb WHERE Rack_guid=@rackid AND staDes_guid=@stguid
--end
IF(@instation=0) AND (@stguid=@stguidreg)
BEGIN
	PRINT '衣架进入原分配的站点, LastTime早期是短日期型的，因参与衣架信息加密，不能变成长日期型'
	UPDATE tRackInf SET InStation=1,InStationLink=0, LastTime=@lastuse, Reserved=RackCode^CAST(@lastuse AS int), Station_guid_Pre=NULL, GetInTime=@now
		WHERE guid=@rackid;
	INSERT tUpdate(TblName, guid, OpCode)
		VALUES('tRackInf', @rackid, 0);
	UPDATE tStation SET RackCnt=RackCnt+1, IsRefreshTerm=1
		WHERE guid=@stguid;
	INSERT tUpdate(TblName, guid, OpCode) 
		VALUES('tStation', @stguid, 0);
	--ADD YZ
	DECLARE @partid int,
			@MoPar_guid uniqueidentifier,
			@PART_guid uniqueidentifier,
			@nowsubguid uniqueidentifier,
			@BATCH INT,
			@partmax int;
	----
	--记录衣架进站时间
	UPDATE preMergeTemp SET RackInTime=GETDATE() WHERE RackInf_guid=@rackid AND [Station_guid]=@stguid
	
	SELECT @nowsubguid=ZdOnline_guid,@BATCH=ISNULL(BATCH,0) FROM tRackInf WHERE GUID=@rackid
	SELECT @PART_guid=dbo.fm_getMoBySub(@nowsubguid),@MoPar_guid=dbo.fm_getMoParBySub(@nowsubguid)
	SELECT @partmax=MAX(PARTID) FROM TMOM  WITH (NOLOCK) WHERE ISPARTS=1 AND MoPar_guid=@MoPar_guid
	SELECT @partid= PARTID FROM TMOM  WITH (NOLOCK) WHERE GUID=@PART_guid AND ISPARTS=1
	IF(@partid=@partmax)
	BEGIN
		UPDATE preMergeTemp SET ISFINISH=1 WHERE [Station_guid]=@stguid and mopar_guid=@MoPar_guid AND BATCH=@BATCH
	END
END
IF (@instlink=0) AND (@stguid=@stguidlnk)
BEGIN
	PRINT '衣架进入桥接站'
	UPDATE tRackInf SET InStation=0, InStationLink=1, LastTime=@lastuse, Reserved=RackCode^CAST(@lastuse AS int), Station_guid_Pre=NULL, GetInTime=@now
		WHERE guid=@rackid;
	INSERT tUpdate(TblName, guid, OpCode)
		VALUES('tRackInf', @rackid, 0);
	UPDATE tStation SET RackCnt=RackCnt+1, IsRefreshTerm=1
		WHERE guid=@stguid;
	INSERT tUpdate(TblName, guid, OpCode) 
		VALUES('tStation', @stguid, 0);
END
ELSE
	UPDATE tStation SET IsRefreshTerm=1 WHERE guid=@stguid;
	
--需求名称：后道分拣需求
--修改时间：20150521
--修改人：zys
declare @CardNo_Fab int;	--匹卡卡号
declare @Fab_MoNo nvarchar(50);	--制单号
declare @CardNo_Fab_Small int;	--小卡卡号
if(@SeqKind=5)		--分拣站
begin
	--获取小卡卡号
	select @CardNo_Fab_Small=tCutBundCard.CardNo,@Fab_MoNo=tCutBundCard.MONo 
	from tRackInf WITH(NOLOCK) left join tBinCardInf WITH(NOLOCK) on tRackInf.BinCardInf_guid=tBinCardInf.guid
	left join tCutBundCard WITH(NOLOCK) on tBinCardInf.CardNo=tCutBundCard.CardNo
	where RackCode=@rackcode^0x5aa5aa55
	order by tRackInf.InsertTime desc;					--根据衣架信息表的插入时间倒序排列，取最新的记录
	--获取该小卡对应的匹卡的卡号
	select @CardNo_Fab=b.CardNo from tCutBundCard b WITH(NOLOCK), (select MONo,CutLotNo,GarPart,OrderNoFabColor from tCutBundCard WITH(NOLOCK) where CardNo=@CardNo_Fab_Small and MONo=@Fab_MoNo) a 
	where b.MONo=a.mono and b.CutLotNo=a.CutLotNo and b.GarPart=a.GarPart and b.OrderNoFabColor=a.OrderNoFabColor AND b.CardType=6

	IF (@CardNo_Fab is not null)	--判断待进站的衣架对应的匹卡是否存在
		begin
			if EXISTS(select top 1 1 from tFabCardSwingInfo WITH(NOLOCK) where CardNo=@CardNo_Fab)	--判断该匹卡在匹卡刷卡信息表中是否存在
				begin
					--更新匹卡刷卡信息表中下线数量字段，以匹卡卡号做为条件
					--如果下线衣物数量小于等于衣物总数
					IF(cast((select top 1 isnull(DownlineCount,0) from tFabCardSwingInfo WITH (NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab) as int)+1<=CAST((select top 1 ISNULL(qty,0) from tCutBundCard WITH(NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab order by InsertTime desc) as int))
						BEGIN
						update tFabCardSwingInfo set DownlineCount= cast((select top 1 isnull(DownlineCount,0) from tFabCardSwingInfo WITH (NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab) as int)+1,	--更新匹卡刷卡信息表中分拣数量字段，设置客户端名称
						SumCount=CAST((select top 1 ISNULL(qty,0) from tCutBundCard WITH(NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab order by InsertTime desc) as int)		--更新匹卡对应的总数量（可能有匹卡数量通过线外系统修改的情况）
						where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab;	--以匹卡卡号做为更新条件		
						END			
					--如果下线衣物数量大于衣物总数，则用衣物总数做为下线衣物数量
					IF(cast((select top 1 isnull(DownlineCount,0) from tFabCardSwingInfo WITH (NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab) as int)+1>CAST((select top 1 ISNULL(qty,0) from tCutBundCard WITH(NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab order by InsertTime desc) as int))
						BEGIN					
						update tFabCardSwingInfo set DownlineCount= CAST((select top 1 ISNULL(qty,0) from tCutBundCard WITH(NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab order by InsertTime desc) as int),	--更新匹卡刷卡信息表中分拣数量字段，设置客户端名称
						SumCount=CAST((select top 1 ISNULL(qty,0) from tCutBundCard  WITH(NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab order by InsertTime desc) as int)		--更新匹卡对应的总数量（可能有匹卡数量通过线外系统修改的情况）
						where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab;	--以匹卡卡号做为更新条件
						END
				end
		end 
		
	IF (@CardNo_Fab_Small is not null)	--判断待进站的衣架对应的匹卡是否存在
	begin
		if EXISTS(select top 1 1 from tFabCardSwingSizeInfo WITH(NOLOCK) where CardNo=@CardNo_Fab_Small)	--判断该小卡在小卡刷卡信息表中是否存在
			begin
				--更新小卡刷卡信息表中下线数量字段，以小卡卡号做为条件
				update tFabCardSwingSizeInfo set DownlineCount= cast((select top 1 isnull(DownlineCount,0) from tFabCardSwingSizeInfo WITH (NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab_Small) as int)+1,	--更新小卡刷卡信息表中分拣数量字段，设置客户端名称
				SumCount=CAST((select top 1 ISNULL(qty,0) from tCutBundCard WITH(NOLOCK) where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab_Small order by InsertTime desc) as int)		--更新小卡对应的总数量（可能有小卡数量通过线外系统修改的情况）
				where MoNo = @Fab_MoNo AND CardNo=@CardNo_Fab_Small;	--以小卡卡号做为更新条件
			end
	end 

end
