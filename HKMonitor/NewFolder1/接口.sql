USE [SUNRISE10_CDB]
GO
/****** Object:  StoredProcedure [dbo].[GSTDataInsert]    Script Date: 06/09/2017 18:25:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[GSTDataInsert]
@scph nvarchar(50)
AS
SET NOCOUNT ON;
--临时表处理
IF OBJECT_ID('tempdb..#tMOM') IS NOT NULL
	DROP TABLE #tMOM;
IF OBJECT_ID('tempdb..#tMODColorSize') IS NOT NULL
	DROP TABLE #tMODColorSize
IF OBJECT_ID('tempdb..#tMOSeqM') IS NOT NULL
	DROP TABLE #tMOSeqM
IF OBJECT_ID('tempdb..#tMOSeqD') IS NOT NULL
	DROP TABLE #tMOSeqD;
IF OBJECT_ID('tempdb..#tMODColorSize1') IS NOT NULL
	DROP TABLE #tMODColorSize1
IF OBJECT_ID('tempdb..#tMOSeqM1') IS NOT NULL
	DROP TABLE #tMOSeqM1
IF OBJECT_ID('tempdb..#tMOSeqD1') IS NOT NULL
	DROP TABLE #tMOSeqD1;
IF OBJECT_ID('tempdb..#tRoute') IS NOT NULL
	DROP TABLE #tRoute
IF OBJECT_ID('tempdb..#tSeqAssign') IS NOT NULL
	DROP TABLE #tSeqAssign	
IF OBJECT_ID('tempdb..#tStAssign') IS NOT NULL
	DROP TABLE #tStAssign
	IF OBJECT_ID('tempdb..#tSeqAssign1') IS NOT NULL
	DROP TABLE #tSeqAssign1	
IF OBJECT_ID('tempdb..#tStAssign1') IS NOT NULL
	DROP TABLE #tStAssign1
IF OBJECT_ID('tempdb..#tPARTMO') IS NOT NULL
	DROP TABLE #tPARTMO
IF OBJECT_ID('tempdb..#tHash') IS NOT NULL
	DROP TABLE #tHash;
IF OBJECT_ID('tempdb..#GSTV_ksjgfa_FRP') IS NOT NULL
	DROP TABLE #GSTV_ksjgfa_FRP;


DECLARE @qty int;
CREATE TABLE #tMOM
(
	guid uniqueidentifier PRIMARY KEY,
	MONo nvarchar(50) NULL,
	scph nvarchar(50) NULL,
	StyleNo nvarchar(100) NULL,
	Qty int NULL,
	Insertor nvarchar(50) NULL,
	IsParts bit NULL,
	InsertTime datetime NULL,
	bLocalInsert bit NULL,
	MoPar_guid uniqueidentifier NULL,
	partID int NULL,
	PartCode nvarchar(200) NULL,
	PartName nvarchar(400) NULL,
	Mo_guid uniqueidentifier NULL,
	IsYez int null,
	Bz int null
	,SAMTotal decimal(18, 4) NULL
);
CREATE TABLE #tRoute
	(
	guid uniqueidentifier PRIMARY KEY,
	MOM_Guid uniqueidentifier NULL,
	Host_guid uniqueidentifier NULL,
	RouteName nvarchar(100) NULL,
	LastTime datetime NULL,
	InsertTime datetime NULL,
	Bz int null
	);--UPDATE #tRoute SET Host_guid='B217B41D-6BDA-4467-B34B-C9AE896430DC'
CREATE TABLE #tGuid
	(
	stguid uniqueidentifier null
	);
DECLARE @MOGUID uniqueidentifier		--制单
		,@STHBGUID uniqueidentifier		--合并站
		,@SRCROUTID uniqueidentifier	--加工方案
		,@SRCSEQMAXASS uniqueidentifier
		,@MO_PAR uniqueidentifier
		,@seqorder int--
		,@SODR INT
		,@LID INT
		,@SEQGUID uniqueidentifier
		,@PRESEQGUID uniqueidentifier
		,@RGUID uniqueidentifier
DECLARE @STFUNC INT
		,@STASGUID uniqueidentifier
		,@TrackCnt int
		,@PID INT
		,@PAX INT
DECLARE @Mo_guid uniqueidentifier		
		,@ID INT
		,@SEQ INT
		,@MONO NVARCHAR(100)
		,@SEQMOLD uniqueidentifier
		,@guid uniqueidentifier
		,@seqmguid uniqueidentifier
		,@ROUTEID uniqueidentifier
		,@OLDROUTEID uniqueidentifier
		,@NEWROUTEID uniqueidentifier
		,@SeqEnd INT
		,@SeqMax INT
		,@SeqMax1 INT
		,@NewPart uniqueidentifier
		,@SrcPart uniqueidentifier
		,@DesPart uniqueidentifier;
SELECT * INTO #GSTV_ksjgfa_FRP FROM yzGST2017.GST_111.dbo.GSTV_ksjgfa_FRP WHERE scph=@scph
SELECT * INTO #GSTV_yjsjhz_FRP FROM yzGST2017.GST_111.dbo.GSTV_yjsjhz_FRP WHERE scph=@scph

IF NOT EXISTS (SELECT TOP 1 1 FROM #GSTV_ksjgfa_FRP WHERE TSLX='Y')
BEGIN
--插入制单
	INSERT INTO #tMOM(GUID,MONO,StyleNo,Qty,Insertor,InsertTime,bLocalInsert,IsParts,Bz)
	SELECT NEWID(),scph,LTRIM(RTRIM(wbkh)),qty,'GST_ZD',getdate(),0,0,1
	FROM  #GSTV_ksjgfa_FRP Group by scph,wbkh,qty

	--插入部件及其所属
	INSERT INTO #tMOM(GUID,scph,MONO,StyleNo,Qty,Insertor,InsertTime,bLocalInsert,IsParts,partID,PartCode,PartName,Mo_guid,Bz)
	SELECT NEWID(),scph,scph+'_'+CONVERT(nvarchar(10),yjh),LTRIM(RTRIM(wbkh)),qty,'GST_BJ',getdate(),0,1,yjh,LTRIM(RTRIM(bjdm)),LTRIM(RTRIM(bjmc)),(SELECT TOP 1 guid FROM #tMOM WHERE MONO=A.scph),1
	FROM  #GSTV_ksjgfa_FRP A Group by scph,wbkh,qty,yjh,bjdm,bjmc

	--初始构建#TMOM表完成 (还没设置父节点)	
	SELECT GUID=NEWID(),MOM_Guid=GUID,MONO,Insertor='Gst',Version='A',EffDate=GETDATE(),InsertTime=GETDATE(),bLocalInsert,Bz=1 INTO #tMOSeqM FROM #tMOM
	UPDATE #tMOSeqM SET guid=B.guid,Bz=0
	FROM #tMOSeqM A, tMOSeqM B WITH(NOLOCK) WHERE A.MOM_Guid=B.MOM_Guid;

	--部件中导入工序--部件代码唯一
	--'tMoSeqD'
	SELECT MOSeqM_guid=A.guid,MOM_Guid=A.MOM_Guid ,B.MONO,B.StyleNo,B.PartCode
	INTO #tPARTMO
	FROM #tMOSeqM A INNER JOIN #tMOM B ON A.MOM_Guid=b.guid
	WHERE B.IsParts=1
	SELECT guid=newid(),MOSeqM_guid,MOM_Guid,MONO,PartCode,Bz=1,SeqNo=B.yjxh,SeqCode=LTRIM(RTRIM(B.gxdm)),SeqName=LTRIM(RTRIM(B.gcbm)),YJBS=B.yjbs
	INTO #tMoSeqD
	FROM #tPARTMO A RIGHT JOIN (SELECT wbkh,bjdm,yjbs=yjxh,yjxh=row_number()over(partition by bjdm order by yjxh),gxdm,gcbm FROM #GSTV_ksjgfa_FRP GROUP BY wbkh,bjdm,yjxh,gxdm,gcbm) B 
		ON A.PartCode=LTRIM(RTRIM(B.bjdm)) AND A.StyleNo=LTRIM(RTRIM(B.wbkh))
	DROP TABLE #tPARTMO

	UPDATE #tMoSeqD SET guid=B.guid,Bz=0
	FROM #tMoSeqD A, tMoSeqD B WITH(NOLOCK) WHERE A.MOSeqM_guid=B.MOSeqM_guid AND A.SeqCode=B.SeqCode;
	
	--为每个部件生成加工方案 (--待站安排完成时赋予主机id)
	INSERT INTO #tRoute(GUID,MOM_Guid,RouteName,LastTime,InsertTime,Bz)
	SELECT NEWID(),GUID,MONO,GETDATE(),GETDATE(),1 FROM #tMOM WHERE IsParts=1
	UPDATE #tRoute SET guid=B.guid,Bz=0
	FROM #tRoute A, tRoute B WITH(NOLOCK) WHERE A.MOM_Guid=B.MOM_Guid AND A.RouteName=B.RouteName
	--构建route完成 未抓取	
	--构建工序安排
	--[#tSeqAssign]]]]]]]]]]]]]]]]
	SELECT IDENTITY(int,1,1) ID, GUID=NEWID(),MOM_Guid=a.MOM_Guid,Route_guid=B.guid,SeqOrder=row_number()over(partition by MOSeqM_guid order by SeqNo) ,bMerge=0,Station_guid_Pre=NULL,SeqNo=A.SeqNo,Bz=1
	INTO #tSeqAssign
	FROM #tMoSeqD A LEFT JOIN #tRoute B ON A.MOM_Guid=B.MOM_Guid
	UPDATE #tSeqAssign SET guid=B.guid,Bz=0
	FROM #tSeqAssign A, tSeqAssign B WITH(NOLOCK) WHERE A.Route_guid=B.Route_guid AND A.SeqNo=B.SeqNo
	--[tStAssign]]]]]]]]]]]]]]]]
	SELECT scph,wbkh,bjdm,yjxh=(SELECT TOP 1 SEQNO FROM #tMoSeqD WHERE YJBS=A.YJXH),lineid,stationid INTO #temp1 
	FROM #GSTV_ksjgfa_FRP A GROUP BY scph,wbkh,bjdm,yjxh,lineid,stationid

	SELECT SeqNo=A.yjxh,MOM_Guid=B.GUID,RouteName=B.MONO,Station_guid=dbo.fm_getStGuid(A.lineid,A.stationid),
	Host_guid=dbo.fm_getHostGuid(A.lineid)
	INTO #temp2
	FROM #temp1 A INNER JOIN #tMOM B ON A.wbkh=B.StyleNo AND A.bjdm =B.PartCode AND A.scph=B.scph
	WHERE B.IsParts=1
	SELECT guid=NEWID(),SeqAssign_guid=C.GUID,Station_guid=A.Station_guid,A.Host_guid,AssignRate=1,StEn=1,StFunc=0,Bz=1,TrackID=1
	INTO #tStAssign FROM #temp2 A INNER JOIN #tRoute B ON A.MOM_Guid=B.MOM_Guid
								RIGHT JOIN #tSeqAssign C ON B.GUID=C.Route_guid AND A.SeqNo=C.SeqNo
	UPDATE #tStAssign SET guid=B.guid,Bz=0
	FROM #tStAssign A, tStAssign B WITH(NOLOCK) WHERE A.SeqAssign_guid=B.SeqAssign_guid AND A.Station_guid=B.Station_guid		
	----为加工方案指定主机
	UPDATE #tRoute SET Host_guid=B.Host_guid
	FROM #tRoute A
	INNER JOIN #tSeqAssign C ON C.Route_guid=A.GUID
	INNER JOIN (SELECT SeqAssign_guid,Host_guid FROM #tStAssign GROUP BY SeqAssign_guid,Host_guid) B ON B.SeqAssign_guid=C.GUID 
						
	--存所有需要合并的(!QUEREN)
	SELECT LID=B.lineid,STID=B.stationid,A.*
	INTO #temp3
	FROM  #GSTV_ksjgfa_FRP A
	Left JOIN  yzGST2017.GST_111.dbo.GSTV_ksjgfa_gxzw B ON A.KSBH=B.KSBH and a.ksbjdm=b.bjdm and a.gxdm=b.gxdm
	WHERE a.remark IS NOT NULL AND A.REMARK <>''
	SELECT scph,wbkh,bjdm,LID,STID,MINSeq=(SELECT TOP 1 ISNULL(SEQNO,1) FROM #tMoSeqD WHERE YJBS= (SELECT top 1 yjxh FROM  #GSTV_ksjgfa_FRP
		WHERE scph=scph AND wbkh=wbkh AND lineid=LID AND stationid=STID AND xm01='Y'
		ORDER BY yjxh)),MINCODE=isnull((SELECT top 1 bjdm FROM  #GSTV_ksjgfa_FRP
			WHERE scph=scph AND wbkh=wbkh AND lineid=LID AND stationid=STID AND xm01='Y'
			ORDER BY yjxh),(SELECT top 1 bjdm FROM  #GSTV_ksjgfa_FRP
			WHERE scph=scph AND wbkh=wbkh AND lineid=LID AND stationid=STID 
			ORDER BY yjxh))
	INTO #temp4
	FROM #temp3
	---2017 4 5 后整为空的问题
	--xiugai  fm_getminseq 和 fm_getmincod
	---
	SELECT A.scph,A.wbkh,A.bjdm,LID,STID,MINSeq,DesPart=B.GUID
	INTO #temp5
	FROM #temp4 A LEFT JOIN #tMOM B ON A.wbkh=B.StyleNo AND A.MINCODE =B.PartCode AND A.scph=B.scph
	CREATE TABLE #tHash
	(
	id int IDENTITY(1,1) PRIMARY KEY,
	SrcPart uniqueidentifier NULL,
	Mo_guid uniqueidentifier NULL,
	LID int NULL,
	STID int NULL,
	DesPart uniqueidentifier NULL,
	MINSeq int null,
	SeqEnd int null,
	IsSeqMax int null,	
	NewPart uniqueidentifier null
	);
	INSERT INTO #tHash(SrcPart,Mo_guid,LID,STID,DesPart,MINSeq,SeqEnd)
	SELECT  SrcPart=B.GUID,B.Mo_guid,LID,STID,DesPart,MINSeq,SeqEnd=0
	FROM #temp5 A INNER JOIN #tMOM B ON A.wbkh=B.StyleNo AND A.bjdm =B.PartCode AND A.scph=B.scph
	WHERE B.BZ=1
	ORDER BY B.Mo_guid,DesPart
	DROP TABLE #temp1;
	DROP TABLE #temp2;
	DROP TABLE #temp3;
	DROP TABLE #temp4;
	DROP TABLE #temp5;
	--够
	
	SELECT  @ID=MAX(ID) FROM #tHash
	WHILE(@ID > 0)
	BEGIN--quan 遍历把非最大的begin-end 设置好 --标记叶子
	SELECT @SrcPart=SrcPart,@Mo_guid=Mo_guid,@DesPart=DesPart,@SEQ=MINSeq FROM  #tHash WHERE ID=@ID
	SELECT @SeqEnd=ISNULL(MIN(MINSeq),1)-1 FROM #tHash WHERE Mo_guid=@Mo_guid AND DesPart=@DesPart AND  MINSeq>@SEQ
	UPDATE #tHash SET SeqEnd=@SeqEnd WHERE ID=@ID
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tHash WHERE DesPart=@SrcPart)
	BEGIN
		UPDATE #tMOM SET IsYez=1 WHERE GUID=@SrcPart AND IsParts=1
	END
	SET @ID=@ID-1
	END
	--循环设置最大的begin-end
	SELECT @ID=MIN(ID) FROM #tHash where MINSeq >1
	WHILE (@ID > 0)
	BEGIN
	SELECT @Mo_guid=Mo_guid,@DesPart=DesPart,@SEQ=MINSeq FROM  #tHash WHERE ID=@ID
	SELECT @SeqMax=MAX(MINSeq) FROM #tHash WHERE Mo_guid=@Mo_guid AND DesPart=@DesPart
	SELECT TOP 1 @ROUTEID=GUID FROM #tRoute WHERE MOM_guid=@DesPart
	SELECT @SeqMax1 =MAX(SeqOrder) FROM #tSeqAssign WHERE Route_guid=@ROUTEID 
	IF(@SEQ=@SeqMax)
	BEGIN
		UPDATE #tHash SET SeqEnd=@SeqMax1,IsSeqMax=1 WHERE ID=@ID
	END
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tHash where MINSeq >1 AND ID>@ID ORDER BY ID)
		BREAK;
	ELSE 
	SELECT TOP 1 @ID=ISNULL(ID,0) FROM #tHash where MINSeq >1 AND ID>@ID ORDER BY ID
	END
	--循环新建制单加工方案 （）
	--2017 4 5 相同目的新建了多次制单的问题
	SELECT  @ID=min(ID) FROM #tHash where SeqEnd <>0
	DECLARE @FLAG INT;
	SET @FLAG=0
	WHILE (@ID > 0)
	BEGIN
	SELECT @Mo_guid=Mo_guid,@DesPart=DesPart,@SEQ=MINSeq,@SeqEnd=SeqEnd FROM  #tHash WHERE ID=@ID
	--2017 4 5 相同目的新建了多次制单的问题
	SET @NewPart=NULL;
	SELECT TOP 1 @NewPart=NewPart FROM #tHash WHERE Mo_guid=@Mo_guid AND DesPart=@DesPart AND MINSeq=@SEQ AND SeqEnd=@SeqEnd AND NewPart IS NOT NULL
	IF (@NewPart IS NULL)
	BEGIN
		--制单表
		SET @guid=NEWID();
		INSERT INTO #tMOM(GUID,MONO,StyleNo,Qty,Insertor,InsertTime,bLocalInsert,IsParts,partID,PartCode,PartName,Mo_guid,Bz)
			SELECT	@guid,scph+'_'+CAST(PARTID AS NVARCHAR)+'('+CAST(@SEQ AS nvarchar)+','+CAST(@SeqEnd AS nvarchar)+')',StyleNo,Qty,Insertor,GETDATE(),0,IsParts,partID,PartCode+'('+CAST(@SEQ AS nvarchar)+','+CAST(@SeqEnd AS nvarchar)+')',PartName+'('+CAST(@SEQ AS nvarchar)+','+CAST(@SeqEnd AS nvarchar)+')',Mo_guid,Bz
			FROM #tMOM WHERE GUID=@DesPart AND Bz=1
		--UPDATE #tMOM SET Insertor='YZ_spiltTemp' WHERE GUID=@DesPart
		
		SELECT @MONO=MONO FROM #tMOM WHERE GUID=@guid
		SELECT TOP 1 @SEQMOLD=GUID FROM #tMOSeqM WHERE MOM_Guid=@DesPart
			--制单详情表Z最后 （一个制单一个详情 没要求）
			--制单版本
		SET @seqmguid=NEWID();
		INSERT INTO #tMOSeqM(GUID,MOM_Guid,MONO,Insertor,Version,EffDate,InsertTime,bLocalInsert,Bz)
			SELECT @seqmguid,@guid,@MONO,'Gst','A',GETDATE(),GETDATE(),bLocalInsert,Bz
			FROM #tMOM WHERE GUID=@guid AND Bz=1
		--UPDATE #tMOSeqM SET Insertor='Tmp' WHERE GUID=@SEQMOLD
			--制单工序
			INSERT INTO #tMOSeqD(guid,MOSeqM_guid, MONo,SeqNo,SeqCode,SeqName,Bz)
			SELECT NEWID(),@seqmguid, @MONO,SeqNo,SeqCode,SeqName,Bz
			FROM #tMOSeqD WHERE MOSeqM_guid=@SEQMOLD AND Bz=1
			--加工方案
			SET @NEWROUTEID=NEWID();
			SELECT @OLDROUTEID=GUID FROM #tRoute WHERE MOM_Guid=@DesPart AND RouteName=(SELECT TOP 1 MONO FROM #tMOM WHERE GUID=@DesPart)
			INSERT INTO #tRoute(GUID,MOM_Guid,RouteName,HOST_GUID,LastTime,InsertTime,Bz)
				SELECT @NEWROUTEID,@guid,@MONO,HOST_GUID,GETDATE(),GETDATE(),Bz 
				FROM #tRoute WHERE MOM_Guid=@DesPart AND Bz=1

		--工序安排只要更新		
		UPDATE #tSeqAssign SET Route_guid=@NEWROUTEID,SeqOrder=SeqOrder-@SEQ+1
			WHERE Route_guid=@OLDROUTEID AND SeqOrder>=@SEQ AND SeqOrder<=@SeqEnd		
		--更新要去的制单	
		UPDATE #tHash SET NewPart= @guid WHERE ID=@ID
	END
	ELSE BEGIN--解决建多次相同的问题
		UPDATE #tHash SET NewPart= @NewPart WHERE ID=@ID
	END
	SET @FLAG=1
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tHash where SeqEnd <>0 AND ID>@ID  ORDER BY ID)
		BREAK;
	ELSE 
	SELECT TOP 1 @ID=ISNULL(ID,0) FROM #tHash where SeqEnd <>0 AND ID>@ID ORDER BY ID
	END
	IF(@FLAG=1)
	BEGIN
	--删除老的
	DELETE FROM #tMOM WHERE GUID=@DesPart
	DELETE FROM #tMOSeqM  WHERE GUID=@SEQMOLD
	DELETE FROM #tMOSeqD  WHERE MOSeqM_guid=@SEQMOLD
	END
	--把左侧源 更新为新生成的最大的
	UPDATE #tHash SET SrcPart =ISNULL(B.NewPart,SrcPart)
	FROM #tHash A
	INNER JOIN (SELECT  DesPart,NewPart FROM #tHash WHERE IsSeqMax=1) B
	ON A.SrcPart=B.DesPart

	--循环将新生成的移动到左边
	SELECT @ID=MIN(ID) FROM #tHash where NewPart IS NOT NULL
	WHILE (@ID > 0)
	BEGIN 
	SELECT @NewPart=NewPart,@Mo_guid=Mo_guid,@DesPart=DesPart,@SEQ=MINSeq,@SeqEnd=SeqEnd FROM  #tHash WHERE ID=@ID
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tHash WHERE SrcPart=@NewPart)
	BEGIN
		INSERT INTO #tHash(SrcPart,Mo_guid,LID,STID,DesPart,NewPart)
			SELECT @NewPart,Mo_guid,LID,STID,DesPart,NewPart
				FROM #tHash WHERE Mo_guid=@Mo_guid AND DesPart=@DesPart AND MINSeq=@SeqEnd+1
	END
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tHash where NewPart IS NOT NULL AND ID>@ID ORDER BY ID)
		BREAK;
	ELSE 
	SELECT TOP 1 @ID=ISNULL(ID,0) FROM #tHash where NewPart IS NOT NULL AND ID>@ID ORDER BY ID
	END

	--循环 与前到工序合并
	SELECT  @ID=MAX(ID) FROM #tSeqAssign
	WHILE(@ID > 0)
	BEGIN
	TRUNCATE TABLE #tGuid
	SET @SODR=1
	SELECT @SEQGUID=GUID, @RGUID=Route_guid,@SODR=SeqOrder FROM #tSeqAssign  WHERE ID=@ID
	IF(@SODR>1)
	BEGIN
		SELECT @PRESEQGUID=GUID FROM #tSeqAssign WHERE Route_guid=@RGUID AND SeqOrder=@SODR-1
		INSERT INTO #tGuid(stguid)
			SELECT Station_guid FROM #tStAssign WHERE SeqAssign_guid=@SEQGUID
			EXCEPT SELECT  Station_guid FROM #tStAssign WHERE SeqAssign_guid=@PRESEQGUID
		IF NOT EXISTS (SELECT TOP 1 1 FROM #tGuid)
		BEGIN
			UPDATE #tSeqAssign SET bMerge=1 WHERE ID=@ID
		END
	END
	SET @ID=@ID-1
	END

	--插入配套工序
	INSERT INTO #tMoSeqD (GUID,MOSeqM_guid,MOM_Guid,SeqNo,SeqCode,SeqName,BZ)
	SELECT NEWID(),MOSeqM_guid,MOM_Guid,9999,'PT','配套工序',1 FROM #tMoSeqD GROUP BY MOSeqM_guid,MOM_Guid
	INSERT INTO  #tSeqAssign(MOM_GUID,GUID,Route_guid,SeqOrder,bMerge,Station_guid_Pre,SeqNo,Bz)
	SELECT MOM_GUID,NEWID(),Route_guid,MAX(SeqOrder)+1,0,NULL,9999,1
	FROM #tSeqAssign GROUP BY ROUTE_GUID,MOM_GUID

	--插入挂片工序
	INSERT INTO #tMoSeqD (GUID,MOSeqM_guid,MOM_Guid,SeqNo,SeqCode,SeqName,BZ)
	SELECT NEWID(),MOSeqM_guid,MOM_Guid,0,'GP','挂片工序',1 FROM #tMoSeqD A INNER JOIN #TMOM B ON A.MOM_GUID=B.GUID WHERE B.IsYez=1  GROUP BY MOSeqM_guid,MOM_Guid
	INSERT INTO  #tSeqAssign(MOM_GUID,GUID,Route_guid,SeqOrder,bMerge,Station_guid_Pre,SeqNo,Bz)
	SELECT MOM_GUID,NEWID(),Route_guid,0,0,NULL,0,1
	FROM #tSeqAssign A INNER JOIN #TMOM B ON A.MOM_GUID=B.GUID WHERE B.IsYez=1 GROUP BY ROUTE_GUID,MOM_GUID

	--循环处理左侧源（建立树结构 并为其指定合并站(工序安排层面)）
	SELECT  @ID=MAX(ID) FROM #tHash
	WHILE(@ID > 0)
	BEGIN
	SELECT @MOGUID=SrcPart,@STHBGUID=dbo.fm_getStGuid(LID,STID),@LID=LID,@MO_PAR=ISNULL(NewPart,DesPart) FROM #tHash WHERE ID=@ID
	--**一个制单只有一个加工方案
	SELECT TOP 1 @SRCROUTID=GUID  FROM #tRoute WHERE  MOM_Guid=@MOGUID
	SELECT @seqorder=MAX(SeqOrder) FROM #tSeqAssign WHERE Route_guid=@SRCROUTID AND bMerge=0
	SELECT @SRCSEQMAXASS=GUID FROM #tSeqAssign WHERE Route_guid=@SRCROUTID AND SeqOrder=@seqorder
	--设置合并站
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tStAssign WHERE SeqAssign_guid=@SRCSEQMAXASS AND Station_guid=@STHBGUID )
	BEGIN
		INSERT INTO #tStAssign (guid,SeqAssign_guid,Station_guid,Host_guid,AssignRate,StEn,StFunc,Bz,TrackID)
			SELECT TOP 1 NEWID(),@SRCSEQMAXASS,@STHBGUID,Host_guid,1,1,7,1,1
				FROM #tStAssign --WHERE SeqAssign_guid=@SRCSEQMAXASS
		--添加储备站
		--IF(@LID=5 OR @LID =6)
		--BEGIN --6-13
		--IF NOT EXISTS (SELECT TOP 1 1 FROM #tStAssign WHERE SeqAssign_guid=@SRCSEQMAXASS AND Station_guid='D38CECF2-2DC1-438A-83BB-CCD40402F2DD' )
		--INSERT INTO #tStAssign (guid,SeqAssign_guid,Station_guid,Host_guid,AssignRate,StEn,StFunc,Bz,TrackID)
		--	SELECT TOP 1 NEWID(),@SRCSEQMAXASS,'D38CECF2-2DC1-438A-83BB-CCD40402F2DD',Host_guid,1,1,1,1,1
		--		FROM #tStAssign --WHERE SeqAssign_guid=@SRCSEQMAXASS
		--END
		IF(@LID=7)
		BEGIN --7-4
		IF NOT EXISTS (SELECT TOP 1 1 FROM #tStAssign WHERE SeqAssign_guid=@SRCSEQMAXASS AND Station_guid='90F555CE-CB53-41ED-8F73-EBF0E8D6D8AA' )
		INSERT INTO #tStAssign (guid,SeqAssign_guid,Station_guid,Host_guid,AssignRate,StEn,StFunc,Bz,TrackID)
			SELECT TOP 1 NEWID(),@SRCSEQMAXASS,'90F555CE-CB53-41ED-8F73-EBF0E8D6D8AA',Host_guid,1,1,1,1,1
				FROM #tStAssign --WHERE SeqAssign_guid=@SRCSEQMAXASS
		--插入小号的储备站 6-13 备用
		IF NOT EXISTS (SELECT TOP 1 1 FROM #tStAssign WHERE SeqAssign_guid=@SRCSEQMAXASS AND Station_guid='D38CECF2-2DC1-438A-83BB-CCD40402F2DD' )
		INSERT INTO #tStAssign (guid,SeqAssign_guid,Station_guid,Host_guid,AssignRate,StEn,StFunc,Bz,TrackID)
			SELECT TOP 1 NEWID(),@SRCSEQMAXASS,'D38CECF2-2DC1-438A-83BB-CCD40402F2DD',Host_guid,1,1,0,1,1
				FROM #tStAssign --WHERE SeqAssign_guid=@SRCSEQMAXASS
		END
		IF(@LID=3)
		BEGIN --3-17
		IF NOT EXISTS (SELECT TOP 1 1 FROM #tStAssign WHERE SeqAssign_guid=@SRCSEQMAXASS AND Station_guid='75B14F18-53AC-49A1-803F-027837E4F539' )
		INSERT INTO #tStAssign (guid,SeqAssign_guid,Station_guid,Host_guid,AssignRate,StEn,StFunc,Bz,TrackID)
			SELECT TOP 1 NEWID(),@SRCSEQMAXASS,'75B14F18-53AC-49A1-803F-027837E4F539',Host_guid,1,1,1,1,1
				FROM #tStAssign --WHERE SeqAssign_guid=@SRCSEQMAXASS
		END
	END
	ELSE BEGIN
		UPDATE #tStAssign SET StFunc=7 WHERE SeqAssign_guid=@SRCSEQMAXASS AND Station_guid=@STHBGUID
	END
	--建立树结构
	UPDATE #tMOM SET MoPar_guid=@MO_PAR
		WHERE GUID=@MOGUID	
	SET @ID=@ID-1
	END


	SELECT IDENTITY(int,1,1) ID, A.*,B.TrackCnt INTO #hbSta FROM #tStAssign A LEFT JOIN TSTATION B ON A.Station_guid=B.GUID WHERE B.SEQKIND=7
	SELECT  @ID=MAX(ID) FROM #hbSta
	WHILE(@ID > 0)
	BEGIN
	SELECT @STASGUID=GUID,@SRCSEQMAXASS=SeqAssign_guid,@TrackCnt=TrackCnt,@STFUNC=STFUNC FROM #hbSta WHERE ID=@ID
	SELECT TOP 1 @SRCROUTID=Route_guid FROM #tSeqAssign WHERE GUID=@SRCSEQMAXASS
	SELECT TOP 1 @MOGUID=MOM_GUID FROM #tRoute WHERE  GUID=@SRCROUTID
	SELECT TOP 1 @MO_PAR=MOPAR_GUID FROM #TMOM WHERE GUID=@MOGUID
	IF(@STFUNC<>7 AND @TrackCnt=3)
		UPDATE  #tStAssign  SET TrackID=3 WHERE GUID=@STASGUID
	IF(@STFUNC=7 AND @TrackCnt>1)
	BEGIN
		SELECT @PID=PARTID FROM #TMOM WHERE GUID=@MOGUID
		SELECT @PAX=MAX(PARTID) FROM #TMOM WHERE MOPAR_GUID=@MO_PAR
		IF(@PID=@PAX)
			UPDATE  #tStAssign  SET TrackID=2 WHERE GUID=@STASGUID
	END
	SET @ID=@ID-1
	END

	DELETE FROM #tSeqAssign  FROM #tSeqAssign A INNER JOIN #TMOM B ON A.MOM_GUID=B.GUID WHERE A.SEQNO=9999 AND B.MoPar_guid IS NULL
	
------------同步实体表--（暂时只管新增）---------
--【tMOM】
UPDATE #tMOM  SET SAMTotal=B.MS FROM #GSTV_yjsjhz_FRP B WHERE partID=b.yjh

INSERT INTO tMOM(guid,MONo,StyleNo,Qty,Insertor,IsParts,InsertTime,bLocalInsert,MoPar_guid,partID,PartCode,PartName,Mo_guid,IsYez,SAMTotal)
	SELECT guid,MONo,StyleNo,Qty,Insertor,IsParts,InsertTime,bLocalInsert,MoPar_guid,partID,PartCode,PartName,Mo_guid,IsYez,SAMTotal FROM #tMOM WHERE Bz=1
SELECT @qty=COUNT(0) FROM #tMOM WHERE Bz=1;	
PRINT '新增的部件制单'+CAST(@qty AS nvarchar)+'条';	
--【tMODColorSize】
--暂时一个制单1个详情
SELECT GUID=NEWID(),MOM_Guid=GUID,Qty=Qty,InsertTime=GETDATE(),bLocalInsert,MONO,Bz=1 INTO #tMODColorSize FROM #tMOM
UPDATE #tMODColorSize SET guid=B.guid,Bz=0
	FROM #tMODColorSize A, tMODColorSize B WITH(NOLOCK) WHERE A.MOM_Guid=B.MOM_Guid;
--开始更新详情表
INSERT INTO tMODColorSize(guid, MOM_Guid, MONo,InsertTime,Qty,bLocalInsert,OrderNo)
	SELECT guid, MOM_Guid, MONo,InsertTime,Qty,0,1
		FROM #tMODColorSize WHERE Bz=1		
SELECT @qty=COUNT(0) FROM #tMODColorSize WHERE Bz=1;	
PRINT '新增的制单详情信息'+CAST(@qty AS nvarchar)+'条';
--UPDATE tMODColorSize SET
--	MOM_Guid=b.MOM_Guid
--	, MONo=b.MONo	
--	, InsertTime=b.InsertTime
--	, bLocalInsert=b.bLocalInsert
--	, Qty=b.Qty
--	FROM tMODColorSize a
--	INNER JOIN #tMODColorSize b ON a.guid=b.guid
--	WHERE b.Bz=0
--SELECT @qty=COUNT(0) FROM #tMODColorSize WHERE Bz=0;	
--PRINT '更新制单详情颜色尺寸信息表'+CAST(@qty AS nvarchar)+'条';
--【tMOSeqM】
INSERT INTO tMOSeqM (GUID,MOM_Guid,MONO,Insertor,Version,InsertTime,bLocalInsert)--EffDate
	SELECT GUID,MOM_Guid,MONO,Insertor,Version,InsertTime,bLocalInsert
		 FROM #tMOSeqM  WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tMOSeqM WHERE Bz=1;		
PRINT '新增版本'+CAST(@qty AS nvarchar)+'条';
--【tMOSeqD】
INSERT INTO tMOSeqD(guid,MOSeqM_guid, MONo,SeqNo,SeqCode,SeqName,bLocalInsert,InsertTime)
	SELECT guid,MOSeqM_guid, MONo,SeqNo,SeqCode,SeqName,0,GETDATE()
		FROM #tMoSeqD WHERE Bz=1		
SELECT @qty=COUNT(0) FROM #tMoSeqD WHERE Bz=1;	
PRINT '新增制单工序表'+CAST(@qty AS nvarchar)+'条';
--UPDATE tMOSeqD SET
--	MOSeqM_guid=b.MOSeqM_guid
--	, MONo=b.MONo	
--	, SeqNo=b.SeqNo
--	, SeqCode=b.SeqCode
--	, SeqName=b.SeqName
--	FROM tMOSeqD a
--	INNER JOIN #tMOSeqD b ON a.guid=b.guid
--	WHERE b.Bz=0
--SELECT @qty=COUNT(0) FROM #tMOSeqD WHERE Bz=0;	
--PRINT '更新制单工序信息'+CAST(@qty AS nvarchar)+'条';
---【tRoute】

INSERT INTO tRouteLine(GUID,ROUTE_GUID,INSERTTIME,LINE_GUID)
	SELECT NEWID(),A.GUID,GETDATE(),B.GUID FROM #tRoute A RIGHT JOIN TLINE B ON A.Host_guid=B.Host_guid WHERE A.BZ=1

INSERT INTO tRoute(GUID,MOM_Guid,Host_guid,RouteName,LastTime,InsertTime)
	SELECT GUID,MOM_Guid,Host_guid,RouteName,LastTime,InsertTime
		FROM #tRoute WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tRoute WHERE Bz=1;	
PRINT '新增加工方案'+CAST(@qty AS nvarchar)+'条'; 
--【tSeqAssign】 
INSERT INTO tSeqAssign(GUID,Route_guid,SeqOrder,bMerge,SeqNo,InsertTime)
	SELECT GUID,Route_guid,SeqOrder,bMerge,SeqNo,GETDATE()
		FROM #tSeqAssign WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tSeqAssign WHERE Bz=1;	
PRINT '新增工序安排'+CAST(@qty AS nvarchar)+'条';
--【tStAssign】
INSERT INTO tStAssign(GUID,SeqAssign_guid,Station_guid,AssignRate,StEn,StFunc,InsertTime,TrackID)
	SELECT GUID,SeqAssign_guid,Station_guid,AssignRate,StEn,StFunc,GETDATE(),TrackID 
		FROM #tStAssign WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tStAssign WHERE Bz=1;	
PRINT '新增站安排'+CAST(@qty AS nvarchar)+'条';

END
ELSE BEGIN
--插入制单
	INSERT INTO #tMOM(GUID,MONO,StyleNo,Qty,Insertor,InsertTime,bLocalInsert,IsParts,Bz)
		SELECT NEWID(),scph,LTRIM(RTRIM(wbkh)),qty,'GST_ZD',getdate(),0,0,1
			FROM  #GSTV_ksjgfa_FRP Group by scph,wbkh,qty
	SELECT GUID=NEWID(),MOM_Guid=GUID,MONO,Insertor='Gst',Version='A',EffDate=GETDATE(),InsertTime=GETDATE(),bLocalInsert,Bz=1 INTO #tMOSeqM1 FROM #tMOM
	UPDATE #tMOSeqM1 SET guid=B.guid,Bz=0
		FROM #tMOSeqM1 A, tMOSeqM B WITH(NOLOCK) WHERE A.MOM_Guid=B.MOM_Guid;
	SELECT guid=NEWID(),MOSEQM_GUID=GUID, MONo,IDENTITY(int,1,1) SeqNo ,SeqCode=gxdm,SeqName=gcbm,bLocalInsert=0,InsertTime=GETDATE(),BZ=1
		INTO #TMOSEQD1
		FROM #tMOSeqM1 A RIGHT JOIN #GSTV_ksjgfa_FRP B ON A.MONO=B.SCPH order by b.yjh,yjxh	
	INSERT INTO #tRoute(GUID,MOM_Guid,host_guid,RouteName,LastTime,InsertTime,Bz)
		SELECT NEWID(),GUID,'B217B41D-6BDA-4467-B34B-C9AE896430DC',MONO,GETDATE(),GETDATE(),1 FROM #tMOM 
	--工序安排
	SELECT IDENTITY(int,1,1) ID, GUID=NEWID(),SeqCode,Route_guid=B.guid,SeqOrder=A.SeqNo,bMerge=0,Station_guid_Pre=NULL,SeqNo=A.SeqNo,Bz=1
	INTO #tSeqAssign1
	FROM #tMoSeqD1 A LEFT JOIN #tRoute B ON A.MONO=B.RouteName
	--站安排
	SELECT guid=NEWID(),SeqAssign_guid=A.GUID,Station_guid=dbo.fm_getStGuid(B.lineid,B.stationid),Host_guid='B217B41D-6BDA-4467-B34B-C9AE896430DC',AssignRate=1,StEn=1,StFunc=0,Bz=1,TrackID=1
		INTO #tStAssign1  FROM #tSeqAssign1 A LEFT JOIN #GSTV_ksjgfa_FRP B ON A.SeqCode=B.GXDM
	 --循环 与前到工序合并
	SELECT  @ID=MAX(ID) FROM #tSeqAssign1
	WHILE(@ID > 0)
	BEGIN
	TRUNCATE TABLE #tGuid
	SET @SODR=1
	SELECT @SEQGUID=GUID, @RGUID=Route_guid,@SODR=SeqOrder FROM #tSeqAssign1  WHERE ID=@ID
	IF(@SODR>1)
	BEGIN
		SELECT @PRESEQGUID=GUID FROM #tSeqAssign1 WHERE Route_guid=@RGUID AND SeqOrder=@SODR-1
		INSERT INTO #tGuid(stguid)
			SELECT Station_guid FROM #tStAssign1 WHERE SeqAssign_guid=@SEQGUID
			EXCEPT SELECT  Station_guid FROM #tStAssign1 WHERE SeqAssign_guid=@PRESEQGUID
		IF NOT EXISTS (SELECT TOP 1 1 FROM #tGuid)
		BEGIN
			UPDATE #tSeqAssign1 SET bMerge=1 WHERE ID=@ID
		END
	END
	SET @ID=@ID-1
	END
	SET IDENTITY_INSERT #tMoSeqD1 ON 
	--SET IDENTITY_INSERT #tSeqAssign1 ON 
	INSERT INTO #tMoSeqD1 (GUID,MOSeqM_guid,SeqNo,SeqCode,SeqName,BZ,bLocalInsert,InsertTime)
	SELECT NEWID(),MOSeqM_guid,0,'GP','挂片工序',1,0,getdate() FROM #tMoSeqD1  GROUP BY MOSeqM_guid
	
	INSERT INTO  #tSeqAssign1(GUID,Route_guid,SeqOrder,bMerge,Station_guid_Pre,SeqNo,Bz)
	SELECT NEWID(),Route_guid,0,0,NULL,0,1
	FROM #tSeqAssign1  GROUP BY ROUTE_GUID

	
	SELECT IDENTITY(int,1,1) ID, A.*,B.TrackCnt INTO #hbSta1 FROM #tStAssign1 A LEFT JOIN TSTATION B ON A.Station_guid=B.GUID WHERE B.SEQKIND=7
	SELECT  @ID=MAX(ID) FROM #hbSta1
	WHILE(@ID > 0)
	BEGIN
	SELECT @STASGUID=GUID,@SRCSEQMAXASS=SeqAssign_guid,@TrackCnt=TrackCnt,@STFUNC=STFUNC FROM #hbSta1 WHERE ID=@ID
	SELECT TOP 1 @SRCROUTID=Route_guid FROM #tSeqAssign1 WHERE GUID=@SRCSEQMAXASS
	SELECT TOP 1 @MOGUID=MOM_GUID FROM #tRoute WHERE  GUID=@SRCROUTID
	SELECT TOP 1 @MO_PAR=MOPAR_GUID FROM #TMOM WHERE GUID=@MOGUID
	IF(@STFUNC<>7 AND @TrackCnt=3)
		UPDATE  #tStAssign1  SET TrackID=3 WHERE GUID=@STASGUID
	SET @ID=@ID-1
	END
--【tMOM】
INSERT INTO tMOM(guid,MONo,StyleNo,Qty,Insertor,IsParts,InsertTime,bLocalInsert,MoPar_guid,partID,PartCode,PartName,Mo_guid,IsYez,SAMTotal)
	SELECT guid,MONo,StyleNo,Qty,Insertor,IsParts,InsertTime,bLocalInsert,MoPar_guid,partID,PartCode,PartName,Mo_guid,IsYez,SAMTotal FROM #tMOM WHERE Bz=1
SELECT @qty=COUNT(0) FROM #tMOM WHERE Bz=1;	
PRINT '新增的部件制单'+CAST(@qty AS nvarchar)+'条';	
--【tMODColorSize】
--暂时一个制单1个详情
SELECT GUID=NEWID(),MOM_Guid=GUID,Qty=Qty,InsertTime=GETDATE(),bLocalInsert,MONO,Bz=1 INTO #tMODColorSize1 FROM #tMOM
UPDATE #tMODColorSize1 SET guid=B.guid,Bz=0
	FROM #tMODColorSize1 A, tMODColorSize B WITH(NOLOCK) WHERE A.MOM_Guid=B.MOM_Guid;
--开始更新详情表
INSERT INTO tMODColorSize(guid, MOM_Guid, MONo,InsertTime,Qty,bLocalInsert,OrderNo)
	SELECT guid, MOM_Guid, MONo,InsertTime,Qty,0,1
		FROM #tMODColorSize1 WHERE Bz=1		
SELECT @qty=COUNT(0) FROM #tMODColorSize1 WHERE Bz=1;	
PRINT '新增的制单详情信息'+CAST(@qty AS nvarchar)+'条';
--UPDATE tMODColorSize SET
--	MOM_Guid=b.MOM_Guid
--	, MONo=b.MONo	
--	, InsertTime=b.InsertTime
--	, bLocalInsert=b.bLocalInsert
--	, Qty=b.Qty
--	FROM tMODColorSize a
--	INNER JOIN #tMODColorSize b ON a.guid=b.guid
--	WHERE b.Bz=0
--SELECT @qty=COUNT(0) FROM #tMODColorSize WHERE Bz=0;	
--PRINT '更新制单详情颜色尺寸信息表'+CAST(@qty AS nvarchar)+'条';
--【tMOSeqM】
INSERT INTO tMOSeqM (GUID,MOM_Guid,MONO,Insertor,Version,InsertTime,bLocalInsert)--EffDate
	SELECT GUID,MOM_Guid,MONO,Insertor,Version,InsertTime,bLocalInsert
		 FROM #tMOSeqM1  WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tMOSeqM1 WHERE Bz=1;		
PRINT '新增版本'+CAST(@qty AS nvarchar)+'条';
--【tMOSeqD】
INSERT INTO tMOSeqD(guid,MOSeqM_guid, MONo,SeqNo,SeqCode,SeqName,bLocalInsert,InsertTime)
	SELECT guid,MOSeqM_guid, MONo,SeqNo,SeqCode,SeqName,0,GETDATE()
		FROM #tMoSeqD1 WHERE Bz=1		
SELECT @qty=COUNT(0) FROM #tMoSeqD1 WHERE Bz=1;	
PRINT '新增制单工序表'+CAST(@qty AS nvarchar)+'条';
--UPDATE tMOSeqD SET
--	MOSeqM_guid=b.MOSeqM_guid
--	, MONo=b.MONo	
--	, SeqNo=b.SeqNo
--	, SeqCode=b.SeqCode
--	, SeqName=b.SeqName
--	FROM tMOSeqD a
--	INNER JOIN #tMOSeqD b ON a.guid=b.guid
--	WHERE b.Bz=0
--SELECT @qty=COUNT(0) FROM #tMOSeqD WHERE Bz=0;	
--PRINT '更新制单工序信息'+CAST(@qty AS nvarchar)+'条';
---【tRoute】

INSERT INTO tRouteLine(GUID,ROUTE_GUID,INSERTTIME,LINE_GUID)
	SELECT NEWID(),A.GUID,GETDATE(),B.GUID FROM #tRoute A RIGHT JOIN TLINE B ON A.Host_guid=B.Host_guid WHERE A.BZ=1

INSERT INTO tRoute(GUID,MOM_Guid,Host_guid,RouteName,LastTime,InsertTime)
	SELECT GUID,MOM_Guid,Host_guid,RouteName,LastTime,InsertTime
		FROM #tRoute WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tRoute WHERE Bz=1;	
PRINT '新增加工方案'+CAST(@qty AS nvarchar)+'条';
--【tSeqAssign】
INSERT INTO tSeqAssign(GUID,Route_guid,SeqOrder,bMerge,SeqNo,InsertTime)
	SELECT GUID,Route_guid,SeqOrder,bMerge,SeqNo,GETDATE()
		FROM #tSeqAssign1 WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tSeqAssign1 WHERE Bz=1;	
PRINT '新增工序安排'+CAST(@qty AS nvarchar)+'条';
--【tStAssign】
INSERT INTO tStAssign(GUID,SeqAssign_guid,Station_guid,AssignRate,StEn,StFunc,InsertTime,TrackID)
	SELECT GUID,SeqAssign_guid,Station_guid,AssignRate,StEn,StFunc,GETDATE(),TrackID 
		FROM #tStAssign1 WHERE Bz=1	
SELECT @qty=COUNT(0) FROM #tStAssign1 WHERE Bz=1;	
PRINT '新增站安排'+CAST(@qty AS nvarchar)+'条';
END


--DROP TABLE #tMODColorSize
--DROP TABLE #tMOSeqM
--DROP TABLE #tMOM;
--DROP TABLE #tMOSeqD;
--DROP TABLE #tRoute;
--DROP TABLE #tSeqAssign
--DROP TABLE #tStAssign
--DROP TABLE #tHash
