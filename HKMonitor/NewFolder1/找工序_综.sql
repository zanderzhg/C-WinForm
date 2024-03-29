USE [SUNRISE10_CDB]
GO
/****** Object:  StoredProcedure [dbo].[pc_RackSearchNextSeq]    Script Date: 05/25/2017 10:13:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--按正常的工序顺序查找下道工序=============================?==========================================--
ALTER PROCEDURE [dbo].[pc_RackSearchNextSeq]
@stguidDes uniqueidentifier OUTPUT,		--输出目标工作站唯一标识
@trackDes tinyint OUTPUT,		--输出目标轨道号
@nextOrd smallint OUTPUT		--输出工序号（工序序号）
--WITH ENCRYPTION
AS
SET NOCOUNT ON;
DECLARE @stguidSrc uniqueidentifier,	--当前工作站唯一标识
		@rackid uniqueidentifier,		--衣架唯一标识
		@subid uniqueidentifier,		--在线制单唯一标识
		@routeid uniqueidentifier,		--制单方案唯一标识
		@qainfguid uniqueidentifier,	--质量保证信息唯一标识
		@lineguidSrc uniqueidentifier,	--当前出衣生产线唯一标识
		@stkind int,					--yz
		@Routeguid uniqueidentifier,	--加工方案
		@partid int,
		@partmax int,					
		@MoPar_guid uniqueidentifier,
		@partsubid uniqueidentifier,
		@PART_guid uniqueidentifier,
		@PRESTATION uniqueidentifier,
		@seqnoSR INT,	
		@ISJOIN BIT,
		@ISDETECTIN BIT,
		--@PARTSEQNO INT,
		@PARTROUTEGUID uniqueidentifier,
		@batch int,
		@isfinish bit;					--是否完成
		

SELECT TOP 1 @lineguidSrc=Line_guid, @stguidSrc=guid,@stkind=SeqKind FROM #tStSrc;		--从工作站临时表中取当前工作站唯一标识
SELECT TOP 1 @ISJOIN=ISJOIN,@ISDETECTIN=ISDETECTIN FROM TSTATION WITH (NOLOCK)	WHERE GUID=@stguidSrc
SELECT TOP 1 @seqnoSR=SeqNo,@batch=isnull(batch,0), @rackid=guid, @subid=ZdOnline_guid,@partsubid=ZdOnline_guid1,@routeid=Route_guid, @qainfguid=QAInf_guid, @isfinish=ISNULL(IsFinished,0),@PRESTATION=Station_guid_Pre
	FROM #tRackSrc;		--从衣架信息临时表中取衣架唯一标识、在线制单唯一标识、制单方案唯一标识、质量保证信息唯一标识、是否完成
IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1 AND @subid<>@partsubid)--切过制单且开启了部件流的 才走
BEGIN
--	合并后的制单
	IF(@stkind=7)
	BEGIN
		SELECT TOP 1 @MoPar_guid=MOM_GUID FROM tMODColorSize WHERE GUID=(SELECT MODCS_Guid FROM tZdOnline WHERE GUID=@subid)
		SELECT TOP 1 @PART_guid=MOM_GUID FROM tMODColorSize WHERE GUID=(SELECT MODCS_Guid FROM tZdOnline WHERE GUID=@partsubid)
		SELECT @partmax=MAX(PARTID) FROM TMOM WHERE ISPARTS=1 AND MoPar_guid=@MoPar_guid
		SELECT @partid= PARTID from TMOM where guid=@PART_guid and ISPARTS=1		
		SELECT TOP 1 @PARTROUTEGUID=ROUTE_GUID FROM TZDONLINE WHERE GUID=@partsubid
		IF (@partid<@partmax)
		BEGIN
			EXEC pc_RackSearchOrigin
				@stguidDes=@stguidDes OUTPUT,
				@trackdes=@trackDes OUTPUT;
			--记录已经打出的合并站部件
			
			UPDATE #tRackSrc SET
				SeqNo=NULL
				,Station_guid=@stguidDes
				,TrackID=@trackDes
				,ZdOnline_guid=@partsubid
				,Route_guid=@PARTROUTEGUID
				,IsFinished=1
				,bEdit=1;
			--回挂片站结束
			--IF EXISTS(SELECT TOP 1 1 FROM [MergeHisTemp])
			--BEGIN
			--	SET @nextOrd=-1; --不让出衣
			--	--RETURN
			--END
			--ELSE BEGIN
			INSERT INTO [SUNRISE10_CDB].[dbo].[MergeHisTemp] ([Station_guid],[Mopar_guid],[Mom_guid],[datetime],[kind],[Rack_guid],batch)
					VALUES(@stguidSrc,@MoPar_guid,@PART_guid,GETDATE(),1,@rackid,@batch)
			--END
			RETURN
		END
		ELSE BEGIN
			IF(@routeid IS NOT NULL)
			BEGIN
				DECLARE @nextseqno1 int
				SELECT top 1 @nextseqno1=SeqNo	FROM tSeqAssign WITH (NOLOCK)					--从工序安排表
					WHERE Route_guid=@routeid AND SeqOrder>1 	ORDER BY SeqOrder ASC;	
				IF(@nextseqno1 IS NOT NULL)
				BEGIN
					EXEC pc_RackSearchStation		--执行根据工序查找可用工位======工序肯定存在
						@routeid = @routeid , -- uniqueidentifier
						@seqno = @nextseqno1 , -- int
						@stguidDes = @stguidDes OUTPUT , -- uniqueidentifier
						@trackDes = @trackDes OUTPUT -- tinyint
					--UPDATE #tRackSrc SET SeqNo=@nextseqno1, Station_guid=@stguidDes, TrackID=@trackDes, bEdit=1;
					IF(@stguidDes IS NOT NULL)
					BEGIN
						DECLARE @guidtmp uniqueidentifier;
						UPDATE tSeqAssign SET @guidtmp=guid, Station_guid_Pre=@stguidDes
							WHERE Route_guid=@routeid AND SeqNo=@nextseqno1 AND
								(Station_guid_Pre IS NULL OR Station_guid_Pre<>@stguidDes);
						IF(@guidtmp IS NOT NULL)
							INSERT INTO tUpdate(TblName, guid, OpCode)
								SELECT 'tSeqAssign', @guidtmp, 0;
						DELETE [SUNRISE10_CDB].[dbo].[MergeHisTemp] WHERE [Station_guid]=@stguidSrc AND [Mopar_guid]=@MoPar_guid AND BATCH=@BATCH
						DELETE [SUNRISE10_CDB].[dbo].[preMergeTemp] WHERE [Station_guid]=@stguidSrc AND [mopar_guid]=@MoPar_guid AND BATCH=@BATCH	--add出去时删
					END
					UPDATE #tRackSrc SET  SeqNo=@nextseqno1, Station_guid=@stguidDes, TrackID=@trackDes, bEdit=1;
					RETURN;
				END
		
			END			
		END
	END	
END
IF(@routeid IS NOT NULL)	--如果制单方案唯一标识不为空
BEGIN
	--print '提取工序列表'
	DECLARE @tSeq table(	--声明工序临时表
		SeqOrder int IDENTITY (1, 1),	--工序序号
		SeqOrder1 INT,  --YZ     真正的顺序号
		guid uniqueidentifier,			--唯一标识
		SeqNo int,						--工序号
		QcResult tinyint,				--质量控制结果
		ActDt datetime,					--活动时间
		Route_guid uniqueidentifier,	 --yz jiagongfanagan
		IsOutputSeq bit);				--是否输出工序
	---慢
	SELECT DISTINCT Route_guid INTO #routeguid FROM #tHisSrc WHERE Route_guid IS NOT NULL
	IF NOT EXISTS(SELECT TOP 1 1 FROM #routeguid WHERE Route_guid=@routeid)
	BEGIN
		INSERT INTO #routeguid VALUES(@routeid)
	END		
	--INSERT INTO @tSeq(guid, SeqNo, ActDt, IsOutputSeq)		--插入工序临时表中（唯一标识、工序号、活动时间、是否输出工序）
	--	SELECT guid, SeqNo, InsertTime, IsOutputSeq			--选择唯一标识、工序号、插入时间、是否输出工序
	--		FROM tSeqAssign WITH (NOLOCK)					--从工序安排表
	--		WHERE Route_guid=@routeid						--以制单方案为条件
	--		--WHERE Route_guid=@routeid OR Route_guid IN (SELECT DISTINCT Route_guid FROM #tHisSrc WHERE Route_guid IS NOT NULL )
	--		ORDER BY SeqOrder ASC;							--按照工序序号正序排列
	INSERT INTO @tSeq(SeqOrder1,guid, SeqNo, ActDt, IsOutputSeq,Route_guid)		--插入工序临时表中（唯一标识、工序号、活动时间、是否输出工序）
		SELECT SeqOrder,guid, SeqNo, InsertTime, IsOutputSeq,b.Route_guid		--选择唯一标识、工序号、插入时间、是否输出工序
			FROM #routeguid a WITH (NOLOCK)					--从工序安排表
			LEFT JOIN tSeqAssign b WITH (NOLOCK) ON a.Route_guid=b.Route_guid
			ORDER BY SeqOrder ASC;	
			
	UPDATE @tSeq SET QcResult=ISNULL(b.QcResult, 0), ActDt=b.ProcessTime	--更新工序临时表的质量控制结果、活动时间字段
		FROM @tSeq a, #tHisSrc b							--从工序临时表和衣架历史信息临时表
		WHERE a.SeqNo=b.SeqNo AND A.Route_guid=B.Route_guid;								--通过工序号做关联
		--Route_guid

	DECLARE @seqguid uniqueidentifier,						--声明工序唯一标识
			@nextseqno int,									--下一工序号
			@qcrlt tinyint;									--质量控制结果
--beiyong fangaong
	SELECT TOP 1 @nextOrd=SeqOrder1, @seqguid=guid, @nextseqno=SeqNo, @qcrlt=QcResult,@Routeguid=Route_guid
		FROM @tSeq WHERE QcResult IN (3,4,5);	--从工序临时表中选择质量控制结果在（3-返工，4-送检，5-定点返工, 指对当前工序进行返工）中的下一工序序号、工序唯一标识、工序号、质量控制结果
	IF(@nextseqno IS NOT NULL)	--如果下一工序号非空
	BEGIN
		--print '有返工，送检，后整返工的工序'
		EXEC pc_RackSearchStation		--执行根据工序查找可用工位======工序肯定存在
			@routeid = @Routeguid , -- uniqueidentifier
			@seqno = @nextseqno , -- int
			@stguidDes = @stguidDes OUTPUT , -- uniqueidentifier
			@trackDes = @trackDes OUTPUT -- tinyint
		UPDATE #tRackSrc SET SeqNo=@nextseqno, Station_guid=@stguidDes, TrackID=@trackDes, bEdit=1;
		RETURN;
	END	
	ELSE IF(ISNULL(@isfinish,0)=0)	--如果未完成
	BEGIN
		--IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1 AND @stkind<>8 AND @ISJOIN=1)
		--BEGIN
		--	SELECT A.GUID INTO #tseqassign
		--		FROM @tSeq A INNER JOIN [tStAssign] B WITH(NOLOCK) ON A.GUID=B.SeqAssign_guid
		--				INNER JOIN [TSTATION] C WITH(NOLOCK)  ON B.STATION_GUID=C.GUID
		--				WHERE C.SEQKIND=7
		--	DELETE FROM @tSeq WHERE GUID IN (SELECT GUID FROM #tseqassign) 
		--END
		--IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1 AND @stkind<>8 AND @ISDETECTIN=1)
		--BEGIN
		--	SELECT A.GUID INTO #tseqassign1
		--		FROM @tSeq A INNER JOIN [tStAssign] B WITH(NOLOCK) ON A.GUID=B.SeqAssign_guid
		--				INNER JOIN [TSTATION] C WITH(NOLOCK)  ON B.STATION_GUID=C.GUID
		--				WHERE C.SEQKIND=7
		--	DELETE FROM @tSeq WHERE GUID IN (SELECT GUID FROM #tseqassign1) 
		--END
		--print '未加工的工序'
		SELECT TOP 1 @nextseqno=SeqNo
			FROM @tSeq a WHERE QcResult IS NULL AND Route_guid=@routeid --YZ 非返工工序在当前加工方案中找
				AND ActDt<=(SELECT ISNULL(lastdt, GETDATE()) FROM 
					(SELECT lastdt=MIN(ActDt) FROM @tSeq WHERE SeqOrder>a.SeqOrder AND QcResult IS NOT NULL) b)
			ORDER BY a.SeqOrder;
		IF(@nextseqno IS NOT NULL)
		BEGIN
			--IF NOT EXISTS (SELECT TOP 1 1 FROM tSeqAssign WHERE Route_guid=@routeid AND seqno=@nextseqno)
			--BEGIN --
			--	IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1)
			--	BEGIN
			--		EXEC pc_RackSearchOrigin1
			--		@stguidDes=@stguidDes OUTPUT,
			--		@trackdes=@trackDes OUTPUT;
			--		UPDATE #tRackSrc SET
			--			SeqNo=NULL
			--		,Station_guid=@stguidDes
			--		,TrackID=@trackDes
			--		,IsFinished=1
			--		,bEdit=1;
			--		--回挂片站结束						
			--	END
			--	RETURN
			--END
			--print '有下道工序'
			SELECT TOP 1 @nextOrd=SeqOrder1 FROM @tSeq WHERE SeqNo=@nextseqno AND Route_guid=@routeid --YZ 非返工工序在当前加工方案中找
			IF(@qainfguid IS NOT NULL)
			BEGIN
				--print '衣架还处于QA状态'
				SELECT @stguidDes=Station_guid_QA, @trackDes=1 FROM tQAInf WITH (NOLOCK) WHERE guid=@qainfguid;
			END
			ELSE
			BEGIN
				--print '衣架处于正常状态'
				DECLARE @seqnotmp int,
						@stguidtmp uniqueidentifier;
				--print '@stguidSrc'
				--print @stguidSrc;
				SELECT TOP 1 @qainfguid=guid, @seqnotmp=SeqNo, @stguidtmp=Station_guid_QA FROM tQAInf WITH (NOLOCK)
					WHERE Station_guid=@stguidSrc AND QAQty>NowCnt AND ISNULL(IsFinished,0)=0 ORDER BY InsertTime;
				--print '@qainfguid'
				--print @qainfguid;
				IF(@qainfguid IS NOT NULL) AND EXISTS(SELECT TOP 1 1 FROM #tHisSrc WHERE SeqNo=@seqnotmp AND Station_guid=@stguidSrc AND ISNULL(QcResult,0) IN (0,1,2))
				BEGIN
					--print '进入QA, QA数量+1, ?trackid'
					UPDATE tQAInf SET NowCnt=NowCnt+1 WHERE guid=@qainfguid;
					SELECT @stguidDes=@stguidtmp, @trackDes=1, @nextOrd=0, @nextseqno=NULL;
				END
				ELSE
				BEGIN
					SET @qainfguid=NULL;
					--print '查找工位'
					EXEC pc_RackSearchStation 
						@routeid, 
						@nextseqno,
						@stguidDes OUTPUT,
						@trackDes OUTPUT;
						
					IF(@stguidDes IS NOT NULL)
					BEGIN
						DECLARE @guidtmp1 uniqueidentifier;
						UPDATE tSeqAssign SET @guidtmp1=guid, Station_guid_Pre=@stguidDes
							WHERE Route_guid=@routeid AND SeqNo=@nextseqno AND
								(Station_guid_Pre IS NULL OR Station_guid_Pre<>@stguidDes);
						IF(@guidtmp1 IS NOT NULL)
							INSERT INTO tUpdate(TblName, guid, OpCode)
								SELECT 'tSeqAssign', @guidtmp1, 0;
					END

				END
			END
			UPDATE #tRackSrc SET QAInf_guid=@qainfguid, SeqNo=@nextseqno, Station_guid=@stguidDes, TrackID=@trackDes, bEdit=1;
			RETURN;
		END
		ELSE
		BEGIN
			--print '衣架加工已完成, 更新款式产量'
			DECLARE @kind tinyint,
					@seqno int;
			SELECT TOP 1 @seqno=SeqNo FROM @tSeq where Route_guid=@routeid ORDER BY ActDt DESC; --yz add where Route_guid=@routeid
			IF EXISTS(SELECT TOP 1 1 FROM #tRackSrc WHERE IsDefective=1)
			BEGIN
				--print '同时记录产量和次品量'
				SET @kind=5;
			END
			ELSE
				SET @kind=1;
			IF EXISTS(SELECT TOP 1 * FROM @tSeq WHERE IsOutputSeq=1)
			BEGIN
				--print '有产量标志的，在这里不输出产量'
				SET @kind = @kind & 0x4;
			END
			IF(@kind <> 0)
			BEGIN
				EXEC pc_RecordOutput
					@subid = @subid, -- uniqueidentifier
					@seqno = @seqno,
					@kind = @kind; -- tinyint
			END
			SET @isfinish=1; 
		END
		SELECT TOP 1 @nextseqno=SeqNo, @nextOrd=1 FROM @tSeq;
	END
END
ELSE
BEGIN
	SELECT @nextseqno=NULL, @nextOrd=1;
END

DECLARE @sortline uniqueidentifier, @tosort bit;
IF(dbo.fg_GetPara(@lineguidSrc, 's10001000')=1)
BEGIN
	
	SELECT @sortline=SortLine_guid FROM tZdOnLine WHERE guid=@subid AND ISNULL(IsSortFinished,0)=0;
	IF(@sortline IS NOT NULL)
	BEGIN
		--print '此衣架需要分拣, 去分拣线'
		SELECT
			a.guid 
			, SeqOrder
			, SeqNo
			, a.InsertTime
			, b.Station_guid
			, ProcessTime=CAST(NULL AS datetime)
			, QcRlt=CAST(NULL AS tinyint)
			INTO #tSort
			FROM tSortSeq a WITH(NOLOCK), tSortAssign b WITH(NOLOCK), tLine c WITH(NOLOCK)
			WHERE a.Host_guid=c.Host_guid AND a.guid=b.SortSeq_guid AND b.Zdonline_guid=@subid AND b.StEn=1 AND c.guid=@sortline
			ORDER BY a.SeqOrder;
		--SELECT * FROM #tsort;
		
		--print '标志已分拣工序'
		UPDATE #tSort SET ProcessTime=b.ProcessTime, QcRlt=b.QcResult
			FROM #tSort a, tSortHis b WITH(NOLOCK)
			WHERE a.SeqNo=b.SeqNo AND b.RackInf_guid=@rackid;
		IF EXISTS(SELECT TOP 1 * FROM #tSort WHERE ProcessTime IS NULL OR QcRlt IN (3,4,5))
			OR NOT EXISTS(SELECT TOP 1 1 FROM #tSort)
		BEGIN
			--因分拣另有算法，这里只取分拣线的的桥接站
			SET @tosort=1;
			SELECT @stguidDes=guid, @trackdes=1 FROM tStation WITH(NOLOCK) WHERE Line_guid=@sortline AND IsJoin=1;
		END
		DROP TABLE #tSort;
	END
END

IF(ISNULL(@tosort,0)=0)
BEGIN
	--print '回到挂衣站点'
	EXEC pc_RackSearchOrigin
		@stguidDes=@stguidDes OUTPUT,
		@trackdes=@trackDes OUTPUT;
END

--print '更新衣架当前位置信息'
UPDATE #tRackSrc SET
	SeqNo=NULL
	,Station_guid=@stguidDes
	,TrackID=@trackDes
	,IsFinished=ISNULL(@isfinish,0)
	,bEdit=1;