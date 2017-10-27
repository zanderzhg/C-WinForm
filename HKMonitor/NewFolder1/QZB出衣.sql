USE [SUNRISE10_CDB]
GO
/****** Object:  StoredProcedure [dbo].[pc_RackOut]    Script Date: 06/21/2017 14:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pc_RackOut]
@hostname nvarchar(50),			--�ͻ�������
@lineSrc tinyint,				--���µ������߱��
@stidSrc tinyint,				--���µĹ���վ���
@rackcode int,					--�¼ܴ���
@outKind tinyint,				--�ύ�ĳ�������, =0�������, =1���¹���, =2��ͨ�������, =3�ʼ칤����¼�, =4�������ʼ�վ
@qcRlt tinyint,					--1�ϸ�, =2����, =3��Ʒ
@failOrd smallint,				--�쳣����
@failCode smallint=0,			--�쳣����
@failStr nvarchar(64)=NULL,		--������ʽ��5,2,4;7,3,6   ��ʾ������5�������õ�2,4������7�������õ�3,6��

@lineOld tinyint OUTPUT,		--���µ������߱��
@stidOld tinyint OUTPUT,		--���µĹ���վ���

@lineDes tinyint OUTPUT,		--Ŀ�������߱��
@stidDes tinyint OUTPUT,		--Ŀ�깤��վ���
@trackDes tinyint OUTPUT,		--Ŀ�������

@stidLnk tinyint OUTPUT,		--����վ���
@trackLnk tinyint OUTPUT,		--���ӹ�����

@nextOrd smallint OUTPUT,		--��һ��������
@canOut tinyint OUTPUT,			--=1 �������¼�; =0���ܳ���
@racksub tinyint OUTPUT,		--=1 stidSrc �¼���, =,�ն˲����¼���, 
@msg nvarchar(100) OUTPUT		--��ʾ��Ϣ
--WITH ENCRYPTION
AS
SET NOCOUNT ON;
----------------------��ʼ��----------------------
SELECT
	@lineOld=0, @stidOld=0,
	@lineDes=0, @stidDes=0, @trackDes=1, 
	@stidLnk=0, @trackLnk=0, 
	@nextOrd=0,  @canOut=1, @racksub=0, @msg='';
DECLARE @now datetime,
		@today smalldatetime,
		@lineguidYZ uniqueidentifier,
		@ston NVARCHAR(255),--�ϼ�վ��
		@lasttime datetime,
		@timediff int,
		@batch int,--����
		@nowsmall smalldatetime;
SET @now=GETDATE();
SELECT @today=CAST(CONVERT(nvarchar, GETDATE(), 112) AS smalldatetime), @nowsmall=@now;
--------------------------���߹���----------------------
SET @batch=0;
SELECT @lineguidYZ=GUID,@ston=WorkLine+'-'+CAST(@stidSrc AS NVARCHAR) FROM tLine WHERE LineID=@lineSrc
IF(dbo.fg_GetPara(@lineguidYZ, 'partsDrive')=1)		--��tPara���п���������
BEGIN
	DECLARE @storgid uniqueidentifier,
			@binCardguid uniqueidentifier,
			@momguid uniqueidentifier,--�Ƶ�
			@yzrouteguid uniqueidentifier,--�ӹ�����
			@modcsguid uniqueidentifier,--�Ƶ�����
			@ZDSUBID uniqueidentifier,--�����Ƶ�
			@MoZdGUID uniqueidentifier,--�����Ƶ�
			@MoPar_guid uniqueidentifier,
			@PartName nvarchar(200),
			@SName nvarchar(200),
			@CName nvarchar(400),
			
			@neststid uniqueidentifier,--��һվ
			@prestid uniqueidentifier,--��һվ
			@Instation bit,
			@STAKIND INT,
			--�㿵�ϲ�վ����ͨվ��
			@seqguid_hb uniqueidentifier,
			@rout_guid_hb uniqueidentifier,
			@seqno_hb int,
			@stfunc_hb int;
	SELECT @storgid=guid,@STAKIND=seqkind FROM tStation WHERE line_guid=@lineguidYZ AND StationID=@stidSrc
	IF(@STAKIND=1)--��Ƭվ 
	BEGIN
		IF(dbo.fg_GetPara(@lineguidYZ, 'onlineWay')=0)
		BEGIN--����ȷ������
			SELECT TOP 1 @binCardguid=BinCardInf_guid,@MoZdGUID=ZdOnline_guid FROM tBinCardHis WHERE Station_guid=@storgid ORDER BY LastUseTime desc
			SELECT @MoPar_guid=MOM_Guid FROM tMODColorSize WHERE GUID=(SELECT MODCS_Guid FROM tzdonline WHERE GUID=@MoZdGUID)
			SELECT TOP 1 @CName=ColorName,@SName=SizeName, @PartName=GarPart FROM tCutBundCard WHERE CardNo= (SELECT CardNo FROM tBinCardInf WHERE GUID = @binCardguid)
			--�Ƶ���ˢ��ʱ�Ѿ����� 
			--����guid --��û�в������Ƶ���û�иò��� ��ʱ����ʾ �� ���������Ƶ�������mopar
			SELECT @momguid=GUID FROM TMOM WHERE PartName=@PartName and Mo_guid=@MoPar_guid and isparts=1
			--�����ӹ�����
			SELECT TOP 1 @yzrouteguid=GUID FROM tRoute where mom_guid=@momguid ORDER BY INSERTTIME DESC
			--��������
			SELECT @modcsguid=GUID FROM tMODColorSize WHERE MOM_Guid=@momguid AND ColorName=@CName AND SizeName=@SName
			--�����Ƶ�����û�� ����
			IF NOT EXISTS (SELECT TOP 1 1 FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0)	
			BEGIN
				EXEC pm_on_InportZdD			
				@lineguid = @lineguidYZ, -- int
				@zddid = @modcsguid, -- �Ƶ�����guid
				@routeid = @yzrouteguid, -- uniqueidentifier
				@orgstguid = @storgid,--@stguidDes , -- �ϼ�վ���guid��
				@sortlineguid =null  -- int	
			END
			--�л��Ƶ������õ�ǰ����
			SELECT TOP 1 @ZDSUBID=GUID FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0
			EXEC pm_on_SetOrigin
				@subid =@ZDSUBID,
				@stguid= @storgid,
				@assign =1,
				@current =1
		END
		ELSE IF(dbo.fg_GetPara(@lineguidYZ, 'onlineWay')=1)
		BEGIN--˳��ȷ������ bug ��ʱ
			SELECT TOP 1 @modcsguid=MODCS_Guid FROM tZdOnline with(Nolock) WHERE dbo.fm_SubIsUp(guid)=1 AND dbo.fm_GetStrOrigin1(guid,@storgid)=@ston  ORDER BY InsertTime DESC
			SELECT @MoPar_guid=MOM_Guid FROM tMODColorSize WHERE GUID=@modcsguid
			IF EXISTS(SELECT TOP 1 1 FROM TMOM WHERE GUID=@MoPar_guid AND ISPARTS=1)
				OR EXISTS(SELECT TOP 1 1 FROM TMOM WHERE MO_GUID=@MoPar_guid OR MOPAR_GUID=@MoPar_guid)
			BEGIN
				IF EXISTS(SELECT TOP 1 1 FROM TMOM WHERE GUID=@MoPar_guid AND ISPARTS=1)
				BEGIN
					SELECT @MoPar_guid=Mo_guid FROM TMOM WHERE GUID=@MoPar_guid
				END	
				ELSE BEGIN--��������
					UPDATE tMOM SET IsOnline=0 ,batch=isnull(batch,0)+1 WHERE Mo_guid=@MoPar_guid AND isparts=1
				END		
				IF NOT EXISTS(SELECT TOP 1 1 FROM tMOM WHERE isparts=1 and Mo_guid=@MoPar_guid and ISNULL(IsOnline,0)=0 and ISNULL(IsYez,0)=1)
				BEGIN --һ��ѭ������
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
				IF(@timediff > 180 or @timediff is null)--�����ظ� ���Ƶ�
				BEGIN
					IF NOT EXISTS (SELECT TOP 1 1 FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0)	
												BEGIN
					EXEC pm_on_InportZdD			
					@lineguid = @lineguidYZ, -- int
					@zddid = @modcsguid, -- �Ƶ�����guid
					@routeid = @yzrouteguid, -- uniqueidentifier
					@orgstguid = @storgid,--@stguidDes , -- �ϼ�վ���guid��
					@sortlineguid =null  -- int	
				END
					--�л��Ƶ������õ�ǰ����
					SELECT TOP 1 @ZDSUBID=GUID FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0
									EXEC pm_on_SetOrigin
					@subid =@ZDSUBID,
					@stguid= @storgid,
					@assign =1,
					@current =1
					UPDATE  TMOM SET IsOnline=1 WHERE GUID=@momguid 
					--ûע����¼��п�
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
	IF(@STAKIND=7 AND @stfunc_hb=7)--�ϲ�վ --
	BEGIN
	IF(@prestid IS NULL OR @prestid<>@storgid)--��һ�γ�������
	BEGIN
		IF(@neststid=@storgid)--�����ظ� ���Ƶ�-- and @Instation=1
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
		IF (@momguid IS NOT NULL)--�úϲ��������
		BEGIN
			SELECT TOP 1 @yzrouteguid=GUID FROM tRoute where mom_guid=@momguid ORDER BY INSERTTIME DESC
			SELECT @modcsguid=GUID FROM tMODColorSize WHERE MOM_Guid=@momguid
			IF NOT EXISTS (SELECT TOP 1 1 FROM tZdOnLine WHERE Route_guid=@yzrouteguid AND MODCS_Guid=@modcsguid AND Line_guid=@lineguidYZ AND SubOver=0)	
			BEGIN
				EXEC pm_on_InportZdD			
				@lineguid = @lineguidYZ, -- int
				@zddid = @modcsguid, -- �Ƶ�����guid
				@routeid = @yzrouteguid, -- uniqueidentifier
				@orgstguid = @storgid,--@stguidDes , -- �ϼ�վ���guid��
				@sortlineguid =null  -- int	
			END
			--�л��Ƶ������õ�ǰ����
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
-----------------------վ����ʱ��----------------------
SELECT 
	c.guid						--����վΨһ��ʶ
	,c.Line_guid				--������Ψһ��ʶ
	,b.Host_guid				--�ͻ���Ψһ��ʶ
	,c.MachineCardID			--�³������
	,c.Employee_guid			--Ա��Ψһ��ʶ
	,c.MachineErrHis_guid		--�³��쳣��ʷ��ϢΨһ��ʶ
	,b.WorkShop					--����
	,b.WorkLine					--������
	,c.StationID				--����վ
	,IsFull						--�Ƿ���վ��0��ʾδ��վ��1��ʾ��վ
	,IsInEnable					--�Ƿ��ܹ���վ��0��ʾ������վ��1��ʾ����վ
	,d.ZdOnline_guid			--�����Ƶ�Ψһ��ʶ
	,e.EmpID					--Ա������
	,c.IsUse					--�Ƿ���á�0��ʾ�����ã�1��ʾ����
	,b.SeqVersion				--����汾
	,NowTime=@now				--��ǰʱ��
	,Today=@today				--��ǰ����
	--
	,IsLed1On					--�Ƿ����ƹ⣨LED��
	,IsRefreshTerm				--�Ƿ�ˢ���ն�
	,IsRefreshStati				--�Ƿ�ˢ�¹���վ
	,c.SeqKind					--��������
	,c.IsJoin					--�Ƿ��Ž�
	,c.RackCnt					--�¼�����
	,c.RackCap					--
	,c.IsAutoOut				--�Ƿ�Ϊ�Զ����¡�0��ʾ���ǣ�1��ʾ��
	,IsPreMerge=isnull(c.IsPreMerge,0)			--�Ƿ���Ԥ�ϲ�վ
	,OutKind=@outKind			--�ύ�ĳ�������, =0�������, =1���¹���, =2��ͨ�������, =3�ʼ칤����¼�, =4�������ʼ�վ
	,b.IsSorting				--�Ƿ�ּ�0��ʾ���ǣ�1��ʾ��
	,bEdit=CAST(0 AS bit)		--�Ƿ�༭��0��ʾ���ɱ༭��1��ʾ���Ա༭
	INTO #tStSrc
	FROM tHost a WITH (NOLOCK)
	INNER JOIN tLine b WITH (NOLOCK) ON a.guid=b.Host_guid AND b.LineID=@lineSrc
	INNER JOIN tStation c WITH (NOLOCK) ON b.guid=c.Line_guid AND c.StationID=@stidSrc
	LEFT JOIN tOrigin d WITH (NOLOCK) ON c.guid=d.Station_guid AND c.Origin_guid=d.guid
	LEFT JOIN tEmployee e WITH (NOLOCK) ON c.Employee_guid=e.guid
	WHERE a.HostName=@hostname;
IF NOT EXISTS(SELECT TOP 1 1 FROM #tStSrc)		--�ж���ʱ�����Ƿ�������
BEGIN
	DROP TABLE #tStSrc;		--�ͷ���ʱ��#tStSrc
	SET @canOut=0;			--���ø�վ���ܳ���
	SELECT @msg=dbo.fl_FormatStr2(NULL, '[{0}-{1}]�Ź�λ�����ڻ�δ����', @lineSrc, @stidSrc);	--������ʾ��Ϣ
	RETURN;
END	
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
SELECT TOP 1		--��ȡ��һ����¼
	guid			--Ψһ��ʶ
	,ICCode=@rackcode	--�¼ܴ���
	,Chk=((RackCode^CAST(LastTime AS int))-Reserved)	--У��λ�����¼ܿ��������������ݽ�����򣬲��뱣���ֶ�����������0����ʾδ�����쳣�����򣬱�ʾ�����쳣
	,NowTime=@now		--��ǰϵͳʱ��
	,Today=@today		--��ǰ����
	,OldStation_guid=Station_guid	--����ǰ�¼����ڹ���վ��Ψһ��ʶ���þ�վ��Ψһ��ʶ����Ϊ����ɹ����£���ǰվ���Ǿ�վ����һ��Ҫȥ��վ����վ��
	,OldTrackID=TrackID		--����ǰ���������Ϊ�ɹ����
	,OldInStation=InStation			--����ǰ����վ����Ϊ������վ
	--
	,BarCode						--����
	,BarGuid						--����Ψһ��ʶ
	,ZdOnline_guid					--�����Ƶ�Ψһ��ʶ
	,ZdOnline_guid1=ZdOnline_guid	--����ϲ�ǰ�����߱�ʶ
	,Route_guid						--�Ƶ�����Ψһ��ʶ
	,SeqNo							--�����
	,Station_guid					--����վΨһ��ʶ
	,TrackID=TrackID				--�����
	,InStation						--���ڹ���վ
	,BinCardInf_guid				--������ϢΨһ��ʶ
	,BinCardOver					--
	,Station_guid_Src				--��ǰվΨһ��ʶ
	,Station_guid_Pre				--SHANGһվΨһ��ʶ
	,QAInf_guid						--������֤��ϢΨһ��ʶ
	,QCFail							--���������Ƿ��쳣��0��ʾ���쳣��1��ʾ���쳣
	,Station_guid_Link				--����վ_Ψһ��ʶ_����
	,InStationLink					--�Ƿ�վ���ʼ졣0��ʾ����վ���ʼ죻1��ʾվ���ʼ�
	,LastTime						--���ִ��ʱ��
	,Reserved						--Ԥ���ֶ�
	,NeedReset						--�Ƿ���Ҫ���á�0��ʾ����Ҫ��1��ʾ��Ҫ
	,IsDefective					--�Ƿ��Ʒ��0��ʾ�Ǵ�Ʒ��1��ʾ�Ǵ�Ʒ
	,IsFinished						--�Ƿ���ɡ�0��ʾδ��ɣ�1��ʾ���
	,InsertTime						--����ʱ��
	,Line_guid_Now					--��ǰ������Ψһ��ʶ
	,PreSeqNo						--��һ�������
	,Batch=isnull(batch,0)					--�¼�����  
	,bEdit=CAST(0 AS bit)			--�Ƿ�ɱ༭��0��ʾ���ɱ༭��1��ʾ���Ա༭
	INTO #tRackSrc					--�¼���Ϣ��ʱ��
	FROM tRackInf WITH (NOLOCK)
	WHERE RackCode=@rackcode^0x5aa5aa55
	ORDER BY InsertTime DESC;


UPDATE #tRackSrc SET OldTrackID=ISNULL(OldTrackID, 1), TrackID=ISNULL(TrackID,1);
---------------------------------------------------------------------------------------
CREATE TABLE #tMsg(			--������Ϣ��ʱ��
	nid int IDENTITY(1,1) NOT NULL,		--����Ψһ��ʶ
	WorkLine nvarchar(50) COLLATE DATABASE_DEFAULT,		--������
	StationID tinyint,									--����վ
	Msg nvarchar(100) COLLATE DATABASE_DEFAULT,			--��Ϣ����
	Way nvarchar(100) COLLATE DATABASE_DEFAULT			--�����ʽ����������
);

--------------------------------------------------------------------------------------

DECLARE @hostguid uniqueidentifier,		--�ͻ���Ψһ��ʶ
		@lineguidSrc uniqueidentifier,	--��ǰ����������Ψһ��ʶ
		@stguidSrc uniqueidentifier,	--��ǰ���¹���վΨһ��ʶ
		@stkind tinyint,				--����վ����
		@issorting bit,					--�Ƿ�ּ�0��ʾ���ǣ�1��ʾ��
		@isjoin bit,		--�Ƿ�Ϊ�Ž�վ��0��ʾ���ǣ�1��ʾ��
		@stguidDes uniqueidentifier,	--Ŀ�깤��վΨһ��ʶ
		@missing bit,					--�Ƿ���ʧ��0��ʾû����ʧ��1��ʾ�Ѿ���ʧ
		@empguid uniqueidentifier,		--Ա��Ψһ��ʶ
		@offcode int,					--�Ǳ�λ����
		@machcode int,					--�³�����
		@macherrguid uniqueidentifier,	--�³��쳣Ψһ��ʶ
		@subguid uniqueidentifier,		--�����Ƶ�Ψһ��ʶ����������ZdOnline_guid
		@Ispremerge bit,
		@isfull bit,
		@isauto bit;					--�Ƿ��Զ����¡�0��ʾ���Զ����£�1��ʾ�Զ�����
		

SELECT @missing=0;		--���øñ���Ϊû����ʧ��״̬
SELECT TOP 1
	@stguidSrc=guid						--��ǰ���¹���վΨһ��ʶ
	,@lineguidSrc=Line_guid				--��ǰ����������Ψһ��ʶ
	,@hostguid=Host_guid				--�ͻ���Ψһ��ʶ
	,@stkind=SeqKind					--��������
	,@isjoin=ISNULL(IsJoin, 0)			--�Ƿ��Žӣ�0��ʾ���Žӣ�1��ʾ�Ž�
	,@machcode=MachineCardID			--�³�����
	,@empguid=Employee_guid				--Ա��Ψһ��ʶ
	,@macherrguid=MachineErrHis_guid	--�³��쳣��ʷ��ϢΨһ��ʶ
	,@subguid=ZdOnline_guid				--�����Ƶ�Ψһ��ʶ
	,@isauto=ISNULL(IsAutoOut, 0)		--�Ƿ��Զ����¡�0��ʾ���Զ���1��ʾ�Զ�
	,@issorting=ISNULL(IsSorting, 0)	--�Ƿ�ּ�0��ʾ���ǣ�1��ʾ��
	,@Ispremerge=ISNULL(IsPreMerge,0)
	FROM #tStSrc;			--��ǰ�����¹���վ��ʱ��
	
select @isfull=isfull from tStation where guid=@stguidSrc
-----------------------------------------------------------------------------

----------------------------�¼���Ϣ�йصı��������͸�ֵ--------------------------------------------------------
DECLARE @rackid uniqueidentifier,		--�¼�Ψһ��ʶ
		@lastuse smalldatetime,			--���ʹ��ʱ��
		@chk int,						--У��λ
		@stguidOld uniqueidentifier,	--�ɵĹ���վΨһ��ʶ
		@trackidOld tinyint,			--�ɵĹ�����
		@stguidLnk uniqueidentifier,	--�Ž�վΨһ��ʶ
		@bInStation bit,				--�Ƿ���վ�ڡ�0��ʾ����վ�ڣ�1��ʾ��վ��
		@bInStLink bit,					--�Ƿ��Žӡ�0��ʾ���Žӣ�1��ʾ�Ž�
		@qainfguid uniqueidentifier,	--������֤��ϢΨһ��ʶ
		@isfinish bit,					--�Ƿ���ɡ�0��ʾδ��ɣ�1��ʾ���
		@routeguid uniqueidentifier,	--����Ψһ��ʶ
		@seqno int;						--������

SELECT @chk=0, @bInStation=0, @bInStLink=0, @isfinish=0;	--���ó�ֵ
SELECT TOP 1 @rackid=guid						--�����¼�Ψһ��ʶ
	, @chk=Chk									--����У��λ
	, @stguidOld=OldStation_guid				--���þ�վΨһ��ʶ
	, @bInStation=ISNULL(InStation,0)			--�����Ƿ���վ�ڡ����Ϊ�գ�������Ϊ0
	, @stguidLnk=Station_guid_Link				--�����Ž�վΨһ��ʶ
	, @bInStLink=ISNULL(InStationLink, 0)		--�����Ƿ����Ž�վ��
	, @qainfguid=QAInf_guid						--����������֤��ϢΨһ��ʶ
	, @isfinish=ISNULL(IsFinished,0)			--�����Ƿ���ɣ�Ĭ��ֵΪδ���
	FROM #tRackSrc;								--���¼���ʱ���л�ȡ������Ϣ


------------------------�¼ܺ��Ƿ�ע�ᣬ�������ִ��ʱ��-------------------------------------------
IF (@rackid IS NULL)	--����¼�Ψһ��ʶΪ�գ��жϸ������ߣ����ң��Ƿ�����ʹ��δע���¼�
BEGIN
	IF(dbo.fg_GetPara(@lineguidSrc, 's00000010')=1)		--��tPara���еĲ���������'s00000010'�ļ�¼����tParaLine���е�ParaValue������ֵ��
	BEGIN
		SET @rackid=NEWID();		--�����¼�Ψһ��ʶ
		IF(dbo.fg_GetPara(@lineguidSrc, 'ktPC')=1)	
		BEGIN
		INSERT INTO tRackInf(guid, RackCode, LastTime, Reserved, InsertTime,Batch)		--���¼���Ϣ���в���һ���¼�¼
			VALUES(@rackid, @rackcode^0x5aa5aa55, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), @now,ISNULL(@batch,0));
		INSERT INTO tUpdate(TblName, guid, OpCode)		--����±��в����ͬ���ϴ����¼���Ϣ���¼�����У�OpCode�ֶ�1Ϊ���ӣ�0Ϊ�޸ģ�-1Ϊɾ��
			VALUES('tRackInf', @rackid, 1);
		INSERT INTO #tRackSrc (guid, ICCode, NowTime, Today, LastTime, Reserved, bEdit,Batch)		--���¼���ʱ���в����¼
			VALUES(@rackid, @rackcode, @now, @today, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), 0,ISNULL(@batch,0));
		END
		ELSE BEGIN
			INSERT INTO tRackInf(guid, RackCode, LastTime, Reserved, InsertTime,Batch)		--���¼���Ϣ���в���һ���¼�¼
				VALUES(@rackid, @rackcode^0x5aa5aa55, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), @now,ISNULL(@batch,0));
			INSERT INTO tUpdate(TblName, guid, OpCode)		--����±��в����ͬ���ϴ����¼���Ϣ���¼�����У�OpCode�ֶ�1Ϊ���ӣ�0Ϊ�޸ģ�-1Ϊɾ��
				VALUES('tRackInf', @rackid, 1);
			INSERT INTO #tRackSrc (guid, ICCode, NowTime, Today, LastTime, Reserved, bEdit,Batch)		--���¼���ʱ���в����¼
				VALUES(@rackid, @rackcode, @now, @today, @nowsmall, @rackcode^0x5aa5aa55^CAST(@nowsmall AS int), 0,ISNULL(@batch,0));
		END
	END
	ELSE
	BEGIN
		SET @canOut=0;		--���ò��ܳ���
		INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--����Ϣ��ʱ���в����¼
			SELECT WorkLine, StationID
				, dbo.fl_FormatStr1(@stguidSrc, '�¼�{0}δע��', dbo.fg_ReDimInt(@rackcode))
				,dbo.fl_FormatStr(@stguidSrc, 'ע�������¼�')
				FROM #tStSrc;	--�ӹ���վ��ʱ���л�ȡ��Ϣ��ʱ������Ҫ����ļ�¼
		EXEC pc_ExitRackOut @msg OUTPUT;		--ִ���˳�RackOutʱ�������ݵĴ洢����
		RETURN;		--���������¼ܳ��£��洢����
	END
END
ELSE BEGIN	--�¼�Ψһ��ʶ��Ϊ��--�����¼���ʱ��
	--�������ƣ���̤���վ����
	--�޸��ˣ�zys
	--�޸�ʱ�䣺2015-7-25
	IF(@stkind=6)		--���վ
		UPDATE #tRackSrc SET @lastuse=LastTime, Reserved=@rackcode^0x5aa5aa55^CAST(@nowsmall AS int), NeedReset=0, bEdit=1;		--������������ʱ��
	ELSE
		UPDATE #tRackSrc SET @lastuse=LastTime, LastTime=@nowsmall, Reserved=@rackcode^0x5aa5aa55^CAST(@nowsmall AS int), NeedReset=0, bEdit=1;
END

------------------------------------------------------------------------------
----------------------------------��������--------------------------------------
IF(@outKind=0 OR @isjoin=1)		--�������
BEGIN	
	SET @missing=1;
END
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-----------------------------------���㴫�书��--------------------------------
-------------------------------------------------------------------------------
DECLARE @p2prlt int;	--�����Ե�����Ϣ�������
EXEC pc_RackP2P			--���㴫��
	@rackcode = @rackcode, -- int
    @missing = @missing, -- tinyint
    @stguidSrc = @stguidSrc, -- uniqueidentifier
    @stguidDes = @stguidDes OUTPUT, -- uniqueidentifier
    @rlt = @p2prlt OUTPUT -- int
-----------------------------------���趨�㴫��-------------------------------------------
IF(@p2prlt = 0)	--���������վ
BEGIN			--��ȡ�¼���ʷ��Ϣ���еĲ������ݽ����¼���ʷ������ʱ��
------------------------------------------------------------------------------------------
    -----------------�¼���ʷ��Ϣ��ʱ��-----------------------------------------
	SELECT
		guid			--Ψһ��ʶ
		,SeqNo			--������
		,MOSeqD_guid	--�Ƶ�������ϸ_Ψһ��ʶ
		,Station_guid	--����վ_Ψһ��ʶ
		,Employee_guid	--Ա��_Ψһ��ʶ
		,ProcessTime	--����ʱ��
		,TrackID		--�����
		,QcResult		--�������ƽ��
		,isQA			--�Ƿ�Ϊ������֤
		,IsMerge		--�Ƿ�����
		,IsSortSeq=CAST(0 AS bit)	--�Ƿ��Ƿּ���
		,Route_guid		--�ӹ����� --addyz ��վ����
		INTO #tHisSrc	--�¼���ʷ��Ϣ��ʱ��
		FROM tRackHis WITH (NOLOCK)
		WHERE RackInf_guid=@rackid;	--�¼�Ψһ��ʶ
	----------------------------------------------------------------------
	IF(@missing=0)	--���û����ʧ�������³����ϵȣ�
		BEGIN
		--------------------------------------------------------------------------------------
			----------------------------------------------------------------------------------
			IF ((@stkind=0) OR (@stkind=1)) AND (@isjoin=0) AND (@machcode IS NULL) AND (dbo.fg_GetPara(@lineguidSrc, 'h00000200')=1)
			BEGIN
				SET @canOut=0;	--���ò��ܳ���
				INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--������Ϣ��
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, 'δˢ�³���, ���ܳ���')
						, dbo.fl_FormatStr(@stguidSrc, '��ˢ�³�����ȡ��Ҫ��ˢ�³�������')
						FROM #tStSrc;
				EXEC pc_ExitRackOut @msg OUTPUT;	--ִ���˳��¼ܳ�վ�Ĵ洢����
				RETURN;
			END
			-----------------------------------------------------------------------------------------

			SELECT TOP 1 @offcode=b.OffStdCode		--ѡ��Ǳ�λ����
				FROM tEmpRecent a WITH (NOLOCK), tOffStdToday b WITH (NOLOCK)	--�����Ա�����Ϣ��ͷǱ�λ��¼��
				WHERE a.OffStdToday_guid=b.guid AND a.guid=@empguid;	--ͨ��Ա��Ψһ��ʶ�ͷǱ�λΨһ��ʶ���й�
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------
			IF ((@offcode > 0) AND EXISTS(SELECT TOP 1 1 FROM tOffStdCode WITH (NOLOCK) WHERE OffStdCode=@offcode AND (IsWork=0 OR IsWork IS NULL)))	--��������ڷǱ�λ״̬
			BEGIN
				IF(dbo.fg_GetPara(@lineguidSrc, 's00004000')=1) AND (@macherrguid IS NULL)	--�����������Խ����Ǳ�λ�����³�δ����
				BEGIN
					EXEC pg_RecordEmpOffStd		--��¼Ա���Ǳ�λ����
						@stguid = @stguidSrc , -- uniqueidentifier
						@isterm = 0 , -- bit
						@empguid = @empguid , -- uniqueidentifier
						@offcode = 0 , -- int
						@now = @now , -- datetime
						@errguid = NULL -- uniqueidentifier
				END
				ELSE	--�������������Խ����Ǳ�λ�����³�����
				BEGIN	
					SET @canOut=0;	--���ò��ܳ���
					INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--������Ϣ��ʱ��
						SELECT WorkLine, StationID
							, dbo.fl_FormatStr(@stguidSrc, '���ڷ������ԷǱ�λ״̬, ���ܳ���')
							, dbo.fl_FormatStr(@stguidSrc, '�л�����λ�������ԷǱ�λ')
							FROM #tStSrc;
					EXEC pc_ExitRackOut @msg OUTPUT;	--ִ���˳��¼ܳ��´洢����
					RETURN;
				END
			END
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------
			-----------------------------------------------------------------------------------------		
			IF(@macherrguid IS NOT NULL)	--����³��쳣Ψһ��ʶ��Ϊ��
			BEGIN
				SET @canOut=0;		--���ò��ܳ���
				INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)		--������Ϣ��ʱ��
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '�³�����, ���ܳ���')
						, dbo.fl_FormatStr(@stguidSrc, '��ȴ��³�ά�����')
						FROM #tStSrc;
				EXEC pc_ExitRackOut @msg OUTPUT;		--ִ���˳��¼ܳ��´洢����
				RETURN;
			END
			
			IF(dbo.fg_GetPara(@lineguidSrc, 'OpenAlarmLed')<>0)		--���������δ�رգ�0-�ر�;1-ÿվ������ʾ;2-������ʾ��
			BEGIN

				UPDATE #tStSrc SET IsLed1On=0, bEdit=1;		--���¹���վ��ʱ�����ñ�����Ϊ�رգ���¼�ɱ༭
			END
			
		
			----------------------------------------------------------------------
			IF(dbo.fg_GetPara(@lineguidSrc, 's10001000')=1)
			BEGIN
				IF(@issorting = 1)	--����Ƿּ�XIAN
				BEGIN
					EXEC pc_SortRackOut		--�ּ�վ���´洢����
						@qcRlt = @qcRlt, -- tinyint
						@failStr = @failStr, -- nvarchar(64)
						@canout = @canout OUTPUT; -- tinyint
					EXEC pc_ExitRackOut @msg OUTPUT;
					RETURN;
				END
			END			
		-------------û��ʧ--------------------------------------------------------------------
		END
		-- ------------------��ͨվ��QCվ�򷵹�----------------------------------
	    -- ----------------------------------------------------------------------
	    IF(@outKind=1)		--���¹��� ��13����ͬ�޿��Ż��ط�
		BEGIN
		-- ----------------------------------------------------------------------
			SET @seqno=NULL;	--���ù����Ϊ��
			SELECT TOP 1 @seqno=SeqNo FROM #tHisSrc WHERE QcResult=3 AND Station_guid=@stguidSrc ;
			IF (@isfinish=0) AND (@seqno IS NOT NULL)	--���δ��ɲ��ҹ���ŷǿ�
			BEGIN
				IF(@empguid IS NULL)	--���Ա��Ψһ��ʶΪ��
				BEGIN
					SELECT @canOut=0;	--���ò��ܳ���
					INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)	--������Ϣ��ʱ��
						SELECT WorkLine, StationID
							, dbo.fl_FormatStr(@stguidSrc, 'վԱ��δ����')
							, dbo.fl_FormatStr(@stguidSrc, '�ش�Ա������')
							FROM #tStSrc;
				END
				ELSE BEGIN
					SELECT TOP 1 @subguid=ZdOnline_guid, @routeguid=Route_guid FROM #tRackSrc;	--���¼���ʱ����ѡ�������Ƶ�Ψһ��ʶ���Ƶ�����Ψһ��ʶ
					EXEC pc_RackRecordSeqHis	--��¼������ǰ����غϲ�����Ķ���
						@subid		= @subguid, -- uniqueidentifier		--�����Ƶ�Ψһ��ʶ
						@routeid	= @routeguid, -- uniqueidentifier	--�Ƶ�����Ψһ��ʶ
						@seqno		= @seqno, -- int	--�����
						@qcfail		= 0, -- bit		--�ʼ��쳣��0��ʾ���쳣
						@missing	= @missing OUTPUT, -- bit	--�Ƿ���ʧ
						@canOut		= @canOut OUTPUT; -- tinyint	--�Ƿ��ܹ���վ
					UPDATE #tRackSrc SET Station_guid=NULL, Station_guid_Pre=@stguidSrc, bEdit=1;
				END
			END
			ELSE IF EXISTS(SELECT TOP 1 1 FROM tStation WITH (NOLOCK) WHERE guid=@stguidSrc AND SeqKind=1)	--����ù���վ���ڲ��ҹ������ͣ�����վ���ͣ��ǹ�Ƭվ
			BEGIN
				
				IF EXISTS(SELECT TOP 1 1 FROM tZdOnLine a WITH (NOLOCK), #tRackSrc b	--�������Ƶ�����¼���ʱ���в�ѯ����
					WHERE a.guid=@subguid AND a.Route_guid=b.Route_guid AND b.Station_guid_Pre=@stguidSrc)	--ͨ�������Ƶ�Ψһ��ʶ���Ƶ�����Ψһ��ʶ��ǰһվ_Ψһ��ʶ�����ֶ���Ϊ��ѯ����
				AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0)	--�ж��¼���ʷ��Ϣ��ʱ����������ͬʱδ���
				BEGIN
					--print '���ڹ�Ƭվ������ʱ, ֻ����һ�ι�Ƭվ�Ĵ���';
					SELECT @missing=1;	--����Ϊ��ʧ
				END
				IF(@missing=0)	--�������ʧ
				BEGIN	
					IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0)	--����¼���ʷ��Ϣ��ʱ��������ͬʱδ���
					BEGIN
						--print '�ǿ��¼�';
						IF (dbo.fg_GetPara(@lineguidSrc, 'h00000002')=1)	--����������������ʾ����ӹ�Ƭվ������¼�ԭ����Ϣ
						BEGIN
							--print '����Ҫ���ʼ������վ�¼�';
							EXEC pc_RackSetWaster @kind=2;		--ִ�д洢���̣���ָ���¼ܴ���ɷ�Ʒ
							--print '�����¼ܴ���'
							EXEC pc_RackRecordNew @canOut OUTPUT;	--ִ�д洢���̣�����վ����
						END
						ELSE BEGIN  --������������������ʾ������ӹ�Ƭվ������¼�ԭ����Ϣ
							--print '����λҪ�󲻳�ʼ�����¹�����¼�, ��Ϊ��©�¼�';
							SELECT @missing=1;	--����Ϊ��ʧ
						END
					END
					ELSE BEGIN  --����¼���ʷ��Ϣ��ʱ��û�����ݻ��������
						--p--rint '���¼ܴ���';
						EXEC pc_RackRecordNew @canOut OUTPUT;		--ִ�д洢���̣�����վ����
					END
				END
			END
			ELSE BEGIN
				--print '�����������Ĺ���վ';
				IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0)	--����¼���ʷ��Ϣ��ʱ��������ͬʱδ���
				BEGIN
				--	print '�ǿ��¼�, ����©�¼�������'
					SELECT @missing=1;	--����Ϊ��ʧ
				END
			END			
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind=2)		--��ͨ�������
		BEGIN
		-- ---------------------���վ�����13��IF��������stkind=6��5-------------------------------------------------		
			IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1)		--��tPara���п���������
			BEGIN
				IF ((@stkind=0) or (@stkind=5) or (@stkind=6)) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc)		--�������վ������0������վ���������¼���ʷ��Ϣ���������ݣ�ͬʱ��վ���¼���ʱ����û�м�¼
						AND NOT EXISTS(SELECT TOP 1 1 FROM #tRackSrc WHERE Station_guid_Pre=@stguidSrc)
				BEGIN
					--print '�ǿ��¼�, ����վ, �¼�δ�����';
					EXEC pc_RackRecordGen @canOut OUTPUT, @missing OUTPUT;		--��ͨվ���¼�
				END	
				ELSE IF(@stkind=7) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc)		--�������վ������0������վ���������¼���ʷ��Ϣ���������ݣ�ͬʱ��վ���¼���ʱ����û�м�¼
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
						EXEC pc_RackRecordMerge @canOut OUTPUT;--�ϲ�վ����
					ELSE
						EXEC pc_RackRecordGen @canOut OUTPUT, @missing OUTPUT;		--��ͨվ���¼�
				END
				ELSE BEGIN
					SELECT @missing=1;--��ѭ������վ�����ҹ����߼�������վʱ����
				END
			END	
			ELSE BEGIN
				IF ((@stkind=0) or (@stkind=5) or (@stkind=6)) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc)		--�������վ������0������վ���������¼���ʷ��Ϣ���������ݣ�ͬʱ��վ���¼���ʱ����û�м�¼
					AND NOT EXISTS(SELECT TOP 1 1 FROM #tRackSrc WHERE Station_guid_Pre=@stguidSrc)
				BEGIN
					--print '�ǿ��¼�, ����վ, �¼�δ�����';
					EXEC pc_RackRecordGen @canOut OUTPUT, @missing OUTPUT;		--��ͨվ���¼�
				END		
				ELSE BEGIN  --���վ���Ͳ�����ͨվ�������¼���ʷ��Ϣ��ʱ����û�м�¼�������¼���Ϣ��ʱ���м�¼
					--print '���¼ܣ����������£������ͨվ������©�¼ܴ���';
					SELECT @missing=1;	--����Ϊ��ʧ����©��
				END
			END
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind=3)		--�ʼ칤����¼�
		BEGIN
		-- ----------------------------------------------------------------------
			--print '�ʼ���¼ܣ�������¼�Finished=1Ҳ����Ҫ�󷵹�'
			IF(@stkind=0) AND (@qcRlt=3)	--���վ��������ͨվ�������������ƽ����3����Ʒ��
			BEGIN
				EXEC pc_RackGenToQC_1		--��ͨվ�ͼ�, ����ָ������Ĺ�λ
					@qcRlt = 3,			--�������ƽ����3����Ʒ��
					@failOrd = @failOrd , -- smallint	--�쳣���
					@failCode = @failCode , -- smallint		--�쳣����
					@failCodeStr = @failStr, -- NVARCHAR(64)	--�쳣��������
					@canOut = @canOut OUTPUT,		--�Ƿ��ܹ���վ
					@missing =@missing OUTPUT;		--�Ƿ���ʧ����©��
			END
			ELSE IF(@stkind=2) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@qainfguid IS NULL)	--�����QCվ�������¼���ʷ��Ϣ��ʱ���������ݣ�ͬʱ������֤��ϢΨһ��ʶΪ��
			BEGIN
				--PRINT 'QC���'
				EXEC pc_RackRecordQC @qcRlt, @failOrd, @failCode, @failStr,
					@canOut OUTPUT, @missing OUTPUT;
			END
			ELSE IF(@stkind=4) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc) AND (@isfinish=0) AND
				EXISTS(SELECT TOP 1 1 FROM tQAInf WITH (NOLOCK) WHERE guid=@qainfguid AND Station_guid_QA=@stguidSrc)
			BEGIN
				--PRINT 'QA���'
				EXEC pc_RackRecordQA @qcRlt, @failOrd, @failCode, @failStr,
					@canOut OUTPUT, @missing OUTPUT;
			END
			ELSE BEGIN
				--print '���¹�λ���ʼ�վ, �������ύ������©�¼�x'
				SET @missing=1;
			END
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind=4)	 		
		BEGIN
		-- ----------------------------------------------------------------------
			-- ------------------��ͨվ��QCվ�򷵹�--------------------------
			IF(dbo.fg_GetPara(@lineguidSrc, 'h00000080')=0)
			BEGIN
				SET @canOut=0;	--���ò��ܳ���
				INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)			--������Ϣ��ʱ��
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '��������ͨվԱ�������¼�')
						, dbo.fl_FormatStr(@stguidSrc, '����Ա��ֹͣ�����¼ܣ�����Ĳ���')
						FROM #tStSrc;
				EXEC pc_ExitRackOut @msg OUTPUT;		--ִ���˳��¼ܳ��´洢����
				RETURN;
			END
			-- --------------------------------------------
			--PRINT '��ͨվ�ͼ�'
			IF(@isfinish=0)  --������¼ܲ����ͼ�
			BEGIN
				IF (dbo.fg_GetPara(@lineguidSrc, 'h00000100')=1)	--Ҫ�󷵵��ʼ�վ����
				BEGIN
					EXEC pc_RackGenToQC_0 @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT;
					IF(@nextOrd=0)
					BEGIN
						SELECT @missing=1;	--�ͼ�ʧ��, ������©�¼�
					END
				END
				ELSE BEGIN			--���������ʼ�ս����
					EXEC pc_RackGenToQC_1 
						@qcRlt = 2,
						@failOrd = @failOrd , -- smallint
						@failCode = @failCode , -- smallint
						@failCodeStr = @failStr, -- NVARCHAR(64)
						@canOut = @canOut OUTPUT,
						@missing =@missing OUTPUT;			    
					SET @outKind=3;		--�������������µ�����
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
							, dbo.fl_FormatStr2(@stguidSrc, 'PTP:[{0}-{1}]�Ź�λ������',@Lid,@Sid)
							, dbo.fl_FormatStr(@stguidSrc, '���������� �ߺ�,վ��')
							FROM #tStSrc;
				END
			
			END
			ELSE BEGIN
				SELECT @canOut=0;
					INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, 'PTP: Ŀ����-վ�����ʽ����')
						, dbo.fl_FormatStr(@stguidSrc, '���������� �ߺ�,վ��')
						FROM #tStSrc;
			END
			DROP TABLE #tLineSta
		END
		--------------------------------------(�������ͷֱ�����)------------------
		IF(@missing=1)		--�����ʧ����©��
		BEGIN
		-- ----------------------------------------------------------------------		
			IF EXISTS(SELECT TOP 1 1 FROM tPTP_qzb WHERE Rack_guid=@rackid)
			BEGIN  --PRP ��Ϊ��Ԥ
				DECLARE @PTPGUID uniqueidentifier;
				SELECT TOP 1 @stguidDes= staDes_guid,@PTPGUID=GUID FROM tPTP_qzb WHERE Rack_guid=@rackid
				--IF(@stguidOld<>@stguidDes)
				--	DELETE FROM  tPTP_qzb WHERE GUID=@PTPGUID
				--ELSE
				UPDATE #tRackSrc SET Station_guid=@stguidDes,bEdit=1;
			END
			--print '������©�¼�'
			ELSE BEGIN
				SET @qainfguid=NULL;	--������֤��ϢΨһ��ʶ
				SELECT TOP 1 @routeguid=Route_guid, @seqno=SeqNo, @stguidDes=Station_guid, @trackDes=TrackID	--ѡ���Ƶ�����Ψһ��ʶ������š�Ŀ�깤��վΨһ��ʶ��Ŀ����Ψһ��ʶ��������֤��ϢΨһ��ʶ
					,@qainfguid=QAInf_guid
					FROM #tRackSrc;		--���¼���Ϣ��ʱ����			
				IF EXISTS(SELECT TOP 1 1 FROM tSeqAssign  WITH (NOLOCK) WHERE SeqNo=@seqno AND Route_guid=@routeguid )	--��������ű��д��ڸ��Ƶ������͹������Ϣ��Ӧ�ļ�¼
				BEGIN
					--print 'ԭ������Ĺ����Դ���';
				-------------------------------------------------------------------------------
					IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc WHERE ISNULL(QcResult,0)<4 AND SeqNo=@seqno AND Route_guid=@routeguid)	--���ݹ���ź��������ƽ����Ϊ��ѯ�������ܹ���ѯ����¼
					BEGIN
						--print 'ԭ���乤���Ѽӹ���, ���������µ�����'
						EXEC pc_RackSearchNextSeq 
								@stguidDes OUTPUT, 
								@trackDes OUTPUT, 
								@nextOrd OUTPUT;
					END
					ELSE IF(@qainfguid IS NOT NULL)----QA������
					BEGIN			
						--print '��������֤, ���������µ�����'
						EXEC pc_RackSearchNextSeq 
								@stguidDes OUTPUT, 
								@trackDes OUTPUT, 
								@nextOrd OUTPUT;
					END
					ELSE BEGIN
						--print 'ԭ������Ĺ���δ�ӹ���'
						---------------���µ����� WHERE�������Ż�-------------------------
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
							OR EXISTS(SELECT TOP 1 1 FROM tStation WITH (NOLOCK) WHERE guid=@stguidDes AND SEQKIND=8)  --ADDYZ ԭ�ȷ���ĵ�վ������ѭ������վ
							--OR (@Ispremerge=1 AND dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1)  --yz Ԥ�ϲ�����
							OR EXISTS(SELECT TOP 1 1 FROM tStAssign WITH (NOLOCK) WHERE SeqAssign_guid=@seqguid AND StEn=1 AND (ISNULL(StFunc,0)=7)) --���乤�����кϲ�վ ֱ����վ
						BEGIN
							--print 'ԭ������Ĺ�λ�����ڻ�ֹͣ����';
							IF EXISTS(SELECT TOP 1 1 FROM #tHisSrc)
							BEGIN
								--print '�¼ܼӹ��������²��ҹ�λ';
								EXEC pc_RackSearchStation 
									@routeguid,
									@seqno,
									@stguidDes OUTPUT,
									@trackDes OUTPUT;
								UPDATE #tRackSrc SET Station_guid=@stguidDes, bEdit=1;
							END
							ELSE BEGIN
								--print '�¼ܻ�δ�ӹ���������Ĺ���վ�����ڣ����·����Ƭվ';
								--DELETE FROM tRackFailHis WHERE RackInf_guid=@rackid;
								--UPDATE #tRackSrc SET BarCode=NULL, BarGuid=NULL, ZdOnline_guid=NULL, Route_guid=NULL, SeqNo=NULL, Station_guid=NULL, TrackID=0, IsDefective=0, bEdit=1;
								EXEC pc_RackSearchNextSeq @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT		--�����
							END
						END
					END			
					-------------------------------------------------------------------------------
				END			
				ELSE BEGIN
					-------------------------------------------------------------------------------
						----print 'ԭ������Ĺ��򲻴���';
					--IF (dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1  AND @stguidDes IS NOT NULL AND @trackDes IS NOT NULL)	--AND @seqno IS  NULL
					--BEGIN
					--	PRINT('��ֹ�����������')
					--END	
					--ELSE BEGIN	
							EXEC pc_RackSearchNextSeq @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT		--�����	
					--END
					-------------------------------------------------------------------------------
				END				
			END
		-- ----------------------------------------------------------------------
		END
		ELSE IF(@outKind<>4 OR @outKind<>5)	--��վ���Ͳ���4-�������ʼ�վ
		BEGIN
			--print '���������µ�����'
			EXEC pc_RackSearchNextSeq @stguidDes OUTPUT, @trackDes OUTPUT, @nextOrd OUTPUT;
		END		
------------------------------------------------------------------------------------------
END
--------------------------���㴫��ͷǶ��㴫�䶼Ҫ��--------------------------------------
------------------------------------------------------------------------------------------
----------------------------------�����š�վ���š�||����һ����ʼ����ʱ�� ������һ��վ���ܽ�վʱ���Ŷ�
DECLARE @seqassguid uniqueidentifier,
		@stassguid uniqueidentifier,
		@thisbegtime datetime;
SELECT TOP 1 @seqassguid=b.guid, @stassguid=c.guid, @thisbegtime=c.BeginReqTime
	FROM #tRackSrc a, tSeqAssign b WITH(NOLOCK), tStAssign c WITH(NOLOCK)
	WHERE a.Route_guid=b.Route_guid AND a.PreSeqNo=b.Seqno AND b.guid=c.SeqAssign_guid AND c.Station_guid=@stguidSrc;

------------------------------------�Ŷӳ�վ-------------------------------------------
IF (@stguidDes IS NULL) AND (@outkind<>0) AND (@canOut=1) AND (@stkind<>4) AND (@stkind<>7) AND (@stkind<>8) AND(@trackDes<>5) AND (@isjoin=0)
 AND ((dbo.fg_GetPara(@lineguidSrc, 'h00000010')=1) OR (@isauto=1))
BEGIN
-------------------------------��Ҫ�Ŷӵȳ�վ-------------------------------------------
	SELECT @canOut=0;
	UPDATE tStAssign SET BeginReqTime=CASE WHEN BeginReqTime IS NULL THEN @now ELSE BeginReqTime END,LastReqTime=@now WHERE guid=@stassguid;
	-----------------------------------------------------------------------------------
	---------------------����ּ���Ҫ�Ż����������ƣ�����Ȼ������ŶӵȺ��վʱ�Ŷ�ʱ��䳤----����ѯ�����ݳ���ı�
	-----------------------------------------------------------------------------------
	IF(dbo.fg_GetPara(@lineguidSrc, 's10001000')=1)
	BEGIN
		IF NOT EXISTS(SELECT TOP 1 1 FROM #tMsg)
		BEGIN
			--�������ƣ�����ּ���Ϣ��ʾ����
			--�޸�ʱ�䣺20150605   2016
			--�޸��ˣ�zys    yz
			DECLARE @SeqKind_Des_Msg int;	--Ŀ��վ����
			SELECT @SeqKind_Des_Msg=SeqKind FROM tStation WHERE guid=@stguidDes;
			IF(@stkind=2)
				BEGIN
					DECLARE @CardNo_Fab_Msg int;	--ƥ������
					DECLARE @Fab_MoNo_Msg nvarchar(50);	--�Ƶ���
					DECLARE @CardNo_Fab_Small_Msg int;	--С������
					DECLARE @FabNo_Msg nvarchar(50);	--ƥ��
					--��ȡС������
					SELECT @CardNo_Fab_Small_Msg=tCutBundCard.CardNo,@Fab_MoNo_Msg=tCutBundCard.MONo 
						FROM tRackInf  WITH(NOLOCK) left join tBinCardInf WITH(NOLOCK) ON tRackInf.BinCardInf_guid=tBinCardInf.guid
						left join tCutBundCard WITH(NOLOCK) ON tBinCardInf.CardNo=tCutBundCard.CardNo
						WHERE RackCode=@rackcode^0x5aa5aa55
						ORDER BY tRackInf.InsertTime DESC;					--�����¼���Ϣ��Ĳ���ʱ�䵹�����У�ȡ���µļ�¼
					--��ȡ��С����Ӧ��ƥ���Ŀ���
					SELECT @CardNo_Fab_Msg=b.CardNo FROM tCutBundCard b WITH(NOLOCK), (SELECT MONo,CutLotNo,GarPart,OrderNoFabColor from tCutBundCard WITH(NOLOCK) where CardNo=@CardNo_Fab_Small_Msg and MONo=@Fab_MoNo_Msg) a 
						WHERE b.MONo=a.mono and b.CutLotNo=a.CutLotNo and b.GarPart=a.GarPart and b.OrderNoFabColor=a.OrderNoFabColor AND b.CardType=6
					--��ȡ��ƥ����ƥ����Ϣ
					SELECT TOP 1 @FabNo_Msg=FabNo from tCutBundCard WITH(NOLOCK) where CardNo=@CardNo_Fab_Msg and MONo=@Fab_MoNo_Msg order by InsertTime desc;
					
					IF (@FabNo_Msg is not null)	--�жϴ���վ���¼ܶ�Ӧ��ƥ���Ƿ����
						BEGIN
							INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
							SELECT WorkLine, StationID
								, dbo.fl_FormatStr(@stguidSrc, '�Ҳ�����λ����վ,�ּ�վˢƥ��'+cast(@FabNo_Msg as varchar(10))+ '��ƥ�������')
								, dbo.fl_FormatStr(@stguidSrc, '')
								FROM #tStSrc;
						END
					ELSE BEGIN
							INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
								SELECT WorkLine, StationID
								, dbo.fl_FormatStr(@stguidSrc, '�ּ����Ҳ�����λ����վ')
								, dbo.fl_FormatStr(@stguidSrc, '�ּ�վˢƥ������վ���¼�')
								FROM #tStSrc;
						END					
				END
				--ELSE BEGIN
				--INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
				--	SELECT WorkLine, StationID
				--		, dbo.fl_FormatStr(@stguidSrc, '�¹����Ҳ�����λ, ����վ, �����ɫ��')
				--		, dbo.fl_FormatStr(@stguidSrc, '����µ�����Ĺ�λ�����������ĳ�������')
				--		FROM #tStSrc;
				--END					
		END
	END	
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '�¹����Ҳ�����λ, ����վ, �����ɫ��')
						, dbo.fl_FormatStr(@stguidSrc, '����µ�����Ĺ�λ�����������ĳ�������')
						FROM #tStSrc;
	-----------------------------------------------------------------------------------
END
ELSE BEGIN
-------------------------------����Ҫ�Ŷӵȳ�վ----------------------------------------
	UPDATE tStAssign SET LastReqTime=@now WHERE guid=@stassguid AND BeginReqTime IS NOT NULL;
END

--
IF (@stguidDes IS NULL) AND (@outkind<>0) AND (@canOut=1)  AND  (@stkind=8)AND (@isjoin=0) and(@isfull=0)
BEGIN
	SELECT @canOut=0;
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '����վû�����貿�� ��ͣ����')
						, dbo.fl_FormatStr(@stguidSrc, '��ȴ�')
						FROM #tStSrc;
END
IF(@nextOrd=-1 AND @stkind=7)
BEGIN --��������ת
	SELECT @canOut=0;
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
					SELECT WorkLine, StationID
						, dbo.fl_FormatStr(@stguidSrc, '�ϲ�վֻ������ǰ��һ��С�Ų���')
						, dbo.fl_FormatStr(@stguidSrc, '��ȴ�')
						FROM #tStSrc;
END
IF(@trackDes=5)
BEGIN --��������ת
	SET @trackDes=1 
	SET @canOut=1;
END

-------------------------------�Ŷ�----------------------------------------
IF(@canOut=1) AND (@outkind<>0)
BEGIN
	--PRINT '�����վʱ���ж��Ƿ���ͬ���������¼����Ŷӵȴ���վ'
	IF EXISTS(SELECT TOP 1 1 FROM tStAssign WITH(NOLOCK)
			WHERE SeqAssign_guid=@seqassguid AND BeginReqTime<@thisbegtime AND DATEDIFF(ss, LastReqTime, @now)<15 )
	BEGIN
		SET @canOut=0;
		UPDATE #tRackSrc SET Station_guid=NULL, @stguidDes=NULL, bEdit=1;
		IF NOT EXISTS(SELECT TOP 1 1 FROM #tMsg)
		BEGIN
			INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
				SELECT WorkLine, StationID
					, dbo.fl_FormatStr(@stguidSrc, 'ͬ�����¼��Ŷӳ�վ')
					, dbo.fl_FormatStr(@stguidSrc, 'ͬ�����¼��Ŷӳ�վ')
					FROM #tStSrc;
		END
	END
END
---------------------------------------------------------------------------------------
DECLARE @bSumRack bit;---1�¼�����1��
SELECT TOP 1 @lineOld=LineID, @stidOld=StationID, @bSumRack=(CASE WHEN a.SumRackTime>@lastuse THEN 0 ELSE 1 END)---@lastuse�¼����ִ��ʱ�䣬SumRackTime�����¼�
	FROM tLine a WITH (NOLOCK), tStation b WITH (NOLOCK)
	WHERE a.guid=b.Line_guid AND b.guid=@stguidOld;
------------------------���ܳ��µĲ���������վ�ڿ�ס������¼�------------------------------------------------
IF(@canOut=0)
BEGIN
	--PRINT '�������վ'
	IF(@bInStation=1)
	BEGIN
		DECLARE @stguidNew uniqueidentifier;
		SELECT TOP 1 @stguidNew=Station_guid FROM #tRackSrc;
		IF (@stguidOld IS NULL AND @stguidNew IS NOT NULL) 
			OR (@stguidOld IS NOT NULL AND @stguidNew IS NULL) 
			OR (@stguidOld<>@stguidNew)
		BEGIN
			--PRINT 'ǰ�η����վ���뱾�η����վ�㲻ͬ�������ԭ����վ������'
			UPDATE #tRackSrc SET InStation=0, bEdit=1;
			--print '�¼�ԭ������վ�ڵģ����ҳɹ����£������ԭ������Ĺ�λվ������'
			IF (@bSumRack=1)
			BEGIN
				PRINT 'rackcnt-1'
				IF(@stguidOld=@stguidSrc)
				BEGIN
					--PRINT '��ǰվ����ԭ�������վ��'
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
--��վ������¼��Ŷ���Ϣ
UPDATE tStAssign SET BeginReqTime=NULL, LastReqTime=NULL WHERE guid=@stassguid;
------------------------------------------------------------------------------------
IF(@missing=0)	--���¼ܷ���ʧ����©��
BEGIN
	--PRINT '������վ���ȥ�����²�����Ϣ'
	UPDATE #tStSrc SET IsRefreshTerm=1, IsRefreshStati=1, bEdit=1;
END
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
--PRINT '�������'
IF(@bInStation=1)
BEGIN
	--------------------------��վ��------------------------------------------------
	UPDATE #tRackSrc SET InStation=0, bEdit=1;
	--print '�¼�ԭ������վ�ڵģ����ҳɹ����£������ԭ������Ĺ�λվ������'
	IF (@bSumRack=1)
	BEGIN
		--PRINT 'stationold rackcnt-1'
		IF(@stguidOld=@stguidSrc)
		BEGIN
			UPDATE #tStSrc SET RackCnt=RackCnt-1, IsRefreshTerm=1, bEdit=1
				WHERE RackCnt>0;
			--PRINT '�ύ��Ϣ��վ��������1'
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
	--------------------------������վ��------------------------------------------------
	UPDATE #tRackSrc SET InStationLink=0, bEdit=1;
	UPDATE tStation SET RackCnt=RackCnt-1, IsRefreshTerm=1 WHERE guid=@stguidLnk AND RackCnt>0;
	INSERT tUpdate(TblName, guid, OpCode)
		SELECT 'tStation', @stguidLnk, 0;
END

IF(@outKind<>0)
BEGIN
	--PRINT '�������ʱ�������Զ�����'
	EXEC pc_ReserevdStationAutoOut;
END
-----------------------����Ŀ���ߺ�վ---------------------------------------
SELECT @stguidLnk=NULL, @trackLnk=0;
DECLARE @lineguidDes uniqueidentifier;
SELECT @lineDes=b.LineID, @stidDes=a.StationID, @lineguidDes=a.Line_guid
	FROM tStation a WITH (NOLOCK), tLine b WITH (NOLOCK)
	WHERE a.guid=@stguidDes AND a.Line_guid=b.guid;
------------------------------------------------------------------------------	
--print '����Ƿ���Ҫ����վ'
IF(@lineguidSrc<>@lineguidDes)
BEGIN
	--print '����Ƿ���Ҫ����վ'
	--PRINT '���Ž�վ'
	EXEC pc_GetBridgeSt 
	    @lineguidSrc = @lineguidSrc , -- uniqueidentifier
	    @lineguidDes = @lineguidDes , -- uniqueidentifier
	    @stguidSrc=@stguidSrc,--YZ 2017 ����Žӵ�����
	    @stguidLnk = @stguidLnk OUTPUT, -- uniqueidentifier
		@trackLnk = @trackLnk OUTPUT;
	IF(@stguidLnk IS NULL)
	BEGIN
		EXEC pc_RecordAlertInf
			@stguid = @stguidSrc
			,@alert =N'�¼ܲ��ܵ���Ŀ���'
			,@solution = N'�����ˮ����������';
	END
	IF(@stguidLnk=@stguidSrc) AND (@outkind<>0)
	BEGIN
		--PRINT '�Ž�վͬʱ������վ'
		SET @stguidLnk = NULL;
	END
	ELSE
		SELECT TOP 1 @stidLnk=StationID FROM tStation WITH (NOLOCK) WHERE guid=@stguidLnk;
END
--------------------------------------------------------------------------------------
UPDATE #tRackSrc SET Station_guid_Link=@stguidLnk, InStationLink=0,TrackID=@trackDes, bEdit=1;
--------------------------------------------------------------------------------------
EXEC pc_ExitRackOut @msg OUTPUT;