USE [SUNRISE10_CDB]
GO
/****** Object:  StoredProcedure [dbo].[pc_RackSearchStation]    Script Date: 06/10/2017 09:02:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
---------------------
ALTER PROCEDURE [dbo].[pc_RackSearchStation]
@routeid uniqueidentIFier,	--制单方案唯一标识
@seqno int,					--工序号

@stguidDes uniqueidentIFier OUTPUT,	--目标工作站唯一标识
@trackDes tinyint OUTPUT			--目标轨道
--WITH ENCRYPTION
AS
SET NOCOUNT ON;

SELECT @stguidDes=NULL, @trackDes=1;	--为目标工作站唯一标识设置初值为空；设置目标轨道初值为1

DECLARE @lineguidSrc uniqueidentIFier,	--当前生产线唯一标识
		@isjoin bit,					--是否桥接
		@stguidSrc uniqueidentIFier,	--当前工作站唯一标识
		@lineguidDes uniqueidentIFier,	--目标生产线唯一标识
		@outkind tinyint,				--出衣类型
		@seqodr int,					--工序序号
		@bmerge bit,					--是否合并工序
		@seqguid uniqueidentIFier,		--工序唯一标识
		@prestguid uniqueidentIFier,	--下一个工作站唯一标识
		@qcrlt tinyint,					--质量控制结果
		@isauto bit,					--是否自动出衣
		@debug bit,						--是否是调试状态
		@ispremerge bit,
		@nowsubguid uniqueidentIFier,
		@premergeStation uniqueidentIFier,--预先合并时目的站
		@rackguid uniqueidentIFier,--yijia
		@batch INT,--[YIJIA PC]YZ
		@stkindsrc int;

--从工作站临时表中取当前生产线唯一标识、当前工作站唯一标识、是否自动出衣、是否桥接、出衣类型
SELECT TOP 1  @ispremerge=IsPreMerge,@stkindsrc=seqkind,@lineguidSrc=Line_guid, @stguidSrc=guid, @isauto=ISNULL(IsAutoOut,0), @isjoin=ISNULL(IsJoin,0), @outkind=OutKind FROM #tStSrc;
SELECT TOP 1  @nowsubguid=ZdOnline_guid,@premergeStation=Station_guid,@rackguid=guid,@batch=Batch FROM #tRackSrc;
--从工序安排表中，根据制单方案唯一标识和工序号做为查询条件，取工序序号、是否合并工序、工序唯一标识、下一个工作站唯一标识
SELECT TOP 1 @seqodr=SeqOrder, @bmerge=ISNULL(bMerge, 0), @seqguid=guid, @prestguid=Station_guid_Pre
		FROM tSeqAssign WITH (NOLOCK) 
		WHERE Route_guid=@routeid AND SeqNo=@seqno;
IF (@bmerge=1)	--如果是合并工序
BEGIN
	--print '与前道工序合并'
	SELECT TOP 1 @seqguid=guid, @prestguid=Station_guid_Pre
		FROM tSeqAssign WITH (NOLOCK)
		WHERE Route_guid=@routeid AND SeqOrder<@seqodr AND ISNULL(bMerge,0)=0 
		ORDER BY SeqOrder DESC;
END

--返工后回原来QC站
SELECT TOP 1 @stguidDes=b.Station_guid, @trackDes=ISNULL(b.TrackID,1) FROM #tRackSrc a, tRackFailHis b WITH (NOLOCK)
	WHERE a.guid=b.RackInf_guid AND b.SeqNo=@seqno and b.QcResult=2 ORDER BY ProcessTime DESC;
IF(@stguidDes IS NOT NULL)
BEGIN
	RETURN;
END
DECLARE @tSt table
(
	nid int IDENTITY(1,1) PRIMARY KEY,
	Line_guid uniqueidentIFier,
	Station_guid uniqueidentIFier,
	TrackID tinyint,
	StFunc tinyint,
	RackCnt0 int,				--线上衣数
	RackCnt int,				--站内衣数
	RackCap int,
	Outcnt int,
	Fpcnt int,
	AssignRate tinyint,
	IsOver bit,
	stkind int,
	AssignPct float
);
INSERT INTO @tSt(Line_guid, Station_guid, TrackID, StFunc, RackCnt0, RackCnt, RackCap, AssignRate, IsOver,stkind,Outcnt,Fpcnt)
	SELECT b.Line_guid
		, a.Station_guid
		, TrackID=ISNULL(a.TrackID,1)
		, StFunc = ISNULL(a.StFunc, 0)
		, RackCnt0=dbo.fm_StRackCnt(a.Station_guid, a.TrackID, 1)			--线上衣数
		, RackCnt=(CASE a.TrackID WHEN 2 THEN b.RackCnt2 WHEN 3 THEN b.RackCnt3 WHEN 4 THEN b.RackCnt4 ELSE b.RackCnt END)
		, RackCap=(CASE a.TrackID WHEN 2 THEN b.RackCap2 WHEN 3 THEN b.RackCap3 WHEN 4 THEN b.RackCap4 ELSE b.RackCap END)
		, AssignRate=ISNULL(a.AssignRate, 1)
		, IsFull=ISNULL((CASE a.TrackID WHEN 2 THEN b.IsFull2 WHEN 3 THEN b.IsFull3 WHEN 4 THEN b.IsFull4 ELSE b.IsFull END),0)
		,b.seqkind
		,Outcnt=dbo.fm_getMergeOutCnt(a.Station_guid)
		,Fpcnt=dbo.fm_getFpCnt(a.Station_guid)
		FROM tStAssign a WITH (NOLOCK)
		INNER JOIN tStation b WITH (NOLOCK) ON a.Station_guid=b.guid AND b.IsInEnable=1 AND b.IsUse=1
		INNER JOIN tLine c WITH (NOLOCK) on b.Line_guid=c.guid
		WHERE a.SeqAssign_guid=@seqguid AND a.StEn=1
		ORDER BY a.StOdr,dbo.fm_getFpCnt(a.Station_guid),c.LineID, b.StationID;

----------------------------------------------------------------------------------------
UPDATE @tSt SET RackCnt=0 WHERE ISNULL(RackCnt, 0)<=0;
UPDATE @tSt SET RackCap=20 WHERE RackCap IS NULL;


--print '减去其自身的数量'
UPDATE @tSt SET RackCnt0=RackCnt0-1
	FROM @tSt a, #tRackSrc b WHERE a.RackCnt0>0 AND a.Station_guid=b.OldStation_guid AND a.TrackID=b.TrackID AND ISNULL(b.OldInStation,0)=0;
UPDATE @tSt SET RackCnt=RackCnt-1
	FROM @tSt a, #tRackSrc b WHERE a.RackCnt>0 AND a.Station_guid=b.OldStation_guid AND a.TrackID=b.TrackID AND ISNULL(b.OldInStation,0)=1;

IF(dbo.fg_GetPara(@lineguidSrc, 'h00100000')=1)                                                                         
BEGIN                                                                                                                   
	--print '判断站点衣架是否满站时，包括线上未进站的衣架'                                                                  
	UPDATE @tSt SET IsOver=(CASE WHEN (RackCnt+RackCnt0)>=RackCap THEN 1 ELSE IsOver END), RackCnt=RackCnt+RackCnt0       
					, AssignPct=(CAST((RackCnt+RackCnt0) AS float)/(CASE WHEN AssignRate=0 THEN 1 ELSE AssignRate END))           
END                                                                                                                     
ELSE                                                                                                                    
BEGIN                                                                                                                   
	UPDATE @tSt SET IsOver=(CASE WHEN RackCnt>=RackCap THEN 1 ELSE IsOver END), RackCnt=RackCnt+RackCnt0                  
					, AssignPct=(CAST((RackCnt+RackCnt0) AS float)/(CASE WHEN AssignRate=0 THEN 1 ELSE AssignRate END))           
END                                                                                                                     
                                                                                                                        
DECLARE @racklow int;                                                                                                   
SELECT @racklow=dbo.fg_GetPara(@lineguidSrc, 'RackLow');	--智能分配站内衣数起点，即站内衣架超过该数量时采用智能分配算法

----------------------------------------------------------------------------------------
--print '先判断当前工序是否返工'
SELECT TOP 1 @qcrlt=ISNULL(QcResult,0) FROM #tHisSrc WHERE SeqNo=@seqno;
IF(@qcrlt=3)	--如果质量控制结果是3-返工
BEGIN
	--print '返工'
	--print '先找专用返工站'
	SELECT TOP 1  @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=3    AND IsOver=0
					ORDER BY AssignPct, nid ASC;
	IF(@stguidDes IS NULL)
	BEGIN
		--print '参数【h00040000】=1，返工衣架送至原加工站点，未选送至原加工员工'
		IF(dbo.fg_GetPara(@lineguidSrc, 'h00040000')=0)
		BEGIN
			--print '送至原站点原员工'
			SELECT TOP 1 @stguidDes=b.guid, @trackDes=ISNULL(a.TrackID,1) FROM #tHisSrc a, tStation b WITH (NOLOCK)
				WHERE a.SeqNo=@seqno AND a.Station_guid=b.guid AND a.Employee_guid=b.Employee_guid;
			IF(@stguidDes IS NULL)
			BEGIN
				--print '送至原员工'
				SELECT TOP 1 @stguidDes=b.guid, @trackDes=1 FROM #tHisSrc a, tStation b WITH (NOLOCK)
					WHERE a.SeqNo=@seqno AND a.Employee_guid=b.Employee_guid;
			END
		END
		ELSE
		BEGIN
			--print '送原站点'
			SELECT TOP 1 @stguidDes=Station_guid, @trackDes=ISNULL(TrackID,1) FROM #tHisSrc WHERE SeqNo=@seqno;
		END
	END
	IF(@stguidDes IS NOT NULL)
	BEGIN
		RETURN;
	END
END
ELSE IF (@qcrlt=4)
BEGIN
	--print '送检衣架, 先找原员工原站点'
	SELECT TOP 1 @stguidDes=b.guid, @trackDes=ISNULL(a.TrackID,1) FROM #tHisSrc a, tStation b WITH (NOLOCK)
		WHERE a.SeqNo=@seqno AND a.Station_guid=b.guid AND a.Employee_guid=b.Employee_guid;
	IF(@stguidDes IS NOT NULL)
	BEGIN
		RETURN;
	END
END
ELSE IF(@qcrlt=5)
BEGIN
	--print '定点返工,只找专用返工站'
	--print '先找专用返工站'
	SELECT TOP 1 @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=3;
	RETURN;
END

IF NOT EXISTS(SELECT TOP 1 1 FROM @tSt)
BEGIN
	IF(dbo.fm_GetSeqOrder(@routeid, @seqno)=1)
	BEGIN
		--print '回到挂衣站点'
		EXEC pc_RackSearchOrigin
			@stguidDes = @stguidDes OUTPUT,
			@trackDes = @trackDes OUTPUT;
		RETURN;
	END
	INSERT INTO #tMsg(WorkLine, StationID, Msg, Way)
		SELECT WorkLine, StationID
			, dbo.fl_FormatStr1(@stguidSrc, '工序[{0}]未分配工位, 或满站, 停止进衣', @seqno)
			, dbo.fl_FormatStr(@stguidSrc, '给工序分配工位, 或允许进衣')
			FROM #tStSrc;
	RETURN;
END

DECLARE @bfIFo bit;
SELECT @bfIFo=dbo.fg_GetPara(@lineguidSrc, 'h00010000');	--在加工产品每工序要分色分码
IF(@bfIFo=0)
BEGIN
	IF(dbo.fg_GetPara(@lineguidSrc, 'h00020000') = 1)
	BEGIN
		--print '判断是否是最后一首工序'
		IF NOT EXISTS(SELECT TOP 1 1 FROM tSeqAssign WITH (NOLOCK)
			WHERE Route_guid=@routeid AND SeqOrder>(SELECT TOP 1 SeqOrder FROM tSeqAssign WITH (NOLOCK) WHERE Route_guid=@routeid AND SeqNo=@seqno))
		BEGIN
			SET @bfIFo=1;
		END
	END
END
IF(@bfIFo=1)
BEGIN
	--print '在加工产品下线时要分色分码';
	DECLARE @proodr int,
			@modcs uniqueidentIFier,
			@inover int,
			@now datetime,
			@indt datetime;

	SELECT TOP 1 @now=NowTime, @proodr=b.processOdr, @modcs=b.MODCS_Guid
		FROM #tRackSrc a, tZdOnLine b WITH (NOLOCK) WHERE a.ZdOnline_guid=b.guid;
	--print '当前产品之前的产品'
	SELECT DISTINCT MODCS_Guid INTO #tmpZdD
		FROM tZdOnLine WITH (NOLOCK) WHERE Line_guid=@lineguidSrc AND ISNULL(SubOver,0)=0
		AND processOdr<@proodr AND MODCS_Guid<>@modcs;

	SELECT @inover=dbo.fg_GetPara(@lineguidSrc, 'InStRackOverMins');	--站内衣架超时时间
	EXEC pc_CalcLineWorkTime
		@lineguid = @lineguidSrc, -- uniqueidentIFier
	    @lenmi = @inover, -- int
	    @dtstart = @indt OUTPUT; -- datetime
	IF(@indt IS NULL)
		SET @indt=@now-3;

	--print '此前各产品的在线衣架信息汇总'
	SELECT b.MODCS_Guid, a.Route_guid, SeqAssign_guid=c.guid, c.SeqOrder, InStation=ISNULL(a.InStation, 0), Qty=COUNT(*)
		INTO #tmpSeqx
		FROM tRackInf a WITH (NOLOCK), tZdOnLine b WITH (NOLOCK), tSeqAssign c WITH (NOLOCK)
		WHERE ISNULL(a.IsFinished,0)=0 AND (ISNULL(InStation,0)=0 OR (InStation=1 AND a.LastTime>@indt))
			AND a.ZdOnline_guid=b.guid AND b.MODCS_Guid IN (SELECT MODCS_Guid FROM #tmpZdD)
			AND a.Route_guid=c.Route_guid AND a.SeqNo=c.SeqNo
		GROUP BY b.MODCS_Guid, a.Route_guid, c.guid, c.SeqOrder, InStation

	--print '排除之前未完成的衣架站点'
	DELETE FROM @tSt WHERE Station_guid IN
		(SELECT c.Station_guid FROM #tmpSeqx a, tSeqAssign b WITH (NOLOCK), tStAssign c WITH (NOLOCK)
			WHERE a.Route_guid=b.Route_guid AND a.SeqOrder<b.SeqOrder AND b.guid=c.SeqAssign_guid);
			
	--print '排除之前有衣架未进站的站点'
	DELETE FROM @tSt WHERE Station_guid IN
		(SELECT Station_guid FROM #tmpSeqx a, tSeqAssign b WITH (NOLOCK), tStAssign c WITH (NOLOCK)
			WHERE ISNULL(a.InStation,0)=0 AND a.Route_guid=b.Route_guid AND a.SeqOrder=b.SeqOrder AND b.guid=c.SeqAssign_guid)
		
	DROP TABLE #tmpZdD;
	DROP TABLE #tmpSeqx;	
END

IF(dbo.fg_GetPara(@lineguidSrc, 'partsDrive')=1)	
BEGIN--部件流 (乔治白定制)
	--逻辑  普通站出来 先找同批次同父亲配对的衣架, 没找到（小号去储备站转 大号主轨上转）
	--		储备站出来（站内有同批次的衣架出 没有回自己）
	--2017 520 改为储备站存大号
	IF EXISTS(SELECT TOP 1 1 FROM @tSt WHERE StFunc=7  )
	BEGIN--该工序下有合并站
		DECLARE @ID INT,@BREAK INT,@hbstaguid uniqueidentIFier,@rackMopar uniqueidentIFier,@rackBatch int;
		DECLARE @partid int,
				@MoPar_guid uniqueidentifier,
				@PART_guid uniqueidentifier,
				@partmin int,
				@TrackID INT,
				@LastInTime DateTime,
				@partmax int;
		SELECT @PART_guid=dbo.fm_getMoBySub(@nowsubguid),@MoPar_guid=dbo.fm_getMoParBySub(@nowsubguid)
		SELECT @partmax=MAX(PARTID),@partmin=MIN(PARTID) FROM TMOM  WITH (NOLOCK) WHERE ISPARTS=1 AND MoPar_guid=@MoPar_guid
		SELECT @partid= PARTID FROM TMOM  WITH (NOLOCK) WHERE GUID=@PART_guid AND ISPARTS=1
		--同一个衣架多次出衣请求
		DELETE FROM [preMergeTemp] WHERE RackInf_guid=@rackguid;--同一个衣架
			UPDATE 	[preMergeTemp] SET 	ISFINISH =0 WHERE BATCH=@BATCH AND mopar_guid=@MoPar_guid AND ISFINISH=1
		UPDATE @tSt SET Outcnt=dbo.fm_getMergeOutCnt(Station_guid),Fpcnt=dbo.fm_getFpCnt(Station_guid) FROM @tSt
		--同一工序下的合并站
		SELECT * INTO #hbStation FROM @tSt WHERE StFunc=7  AND IsOver=0 ORDER BY Fpcnt ASC
		--先找同批次同父亲配对的衣架
		SELECT @ID= min(NID) FROM #hbStation
		WHILE @ID IS NOT NULL
		BEGIN						
			SET @BREAK=@ID
			SELECT @hbstaguid=Station_guid FROM #hbStation where nid=@ID
			--循环开始  --合并站里面衣架和出去的衣架（有相同批次的）
			IF EXISTS(SELECT TOP 1 1 FROM MergeHisTemp  A LEFT JOIN tRackInf B ON A.Rack_guid=B.GUID 
						WHERE A.Station_guid=@hbstaguid AND Mopar_guid=@MoPar_guid AND ISNULL(ISNULL(B.batch,A.batch),0)=@batch)
			BEGIN --合并站出去的直接分  前提：（每个合并站只允许提前出去一个小号部件）
				SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM #hbStation where nid=@ID	
				BREAK;
			END
			--站内的按进站顺序分配
			SELECT TOP 1 @rackMopar=dbo.fm_getMoParBySub(ZdOnline_guid),@rackBatch=isnull(isnull(a.batch,b.batch),0) 
					FROM tRackInf A LEFT JOIN preMergeTemp B ON A.GUID=B.RackInf_guid 
					WHERE A.Station_guid=@hbstaguid AND A.InStation=1 AND ISNULL(B.ISFINISH,0)=0 AND B.[RackInTime] IS NOT NULL
					ORDER BY B.RackInTime ASC,A.LastTime ASC
			IF(@rackMopar=@MoPar_guid AND @rackBatch=@batch)
			BEGIN
				SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM #hbStation where nid=@ID	
				BREAK;
			END 
			--循环结束	
			SELECT top 1 @ID=NID FROM #hbStation WHERE nid>@ID order by nid asc;
			IF(@BREAK=@ID)
			BEGIN
				SET @ID = NULL;
			END
		END
		IF(@stkindsrc=8 AND @outkind<>0)
		BEGIN--内循环储备站		
			IF(@partid<@partmax)--小号 （当先做完（时间短）的做完会进储备站）
			BEGIN
				IF(@stguidDes IS NOT NULL)
				BEGIN
				INSERT INTO [preMergeTemp]([Station_guid],[part_guid],[mopar_guid],[datetime],[guid],[merge_stid],[RackInf_guid],BATCH)
					VALUES(@stguidDes,@PART_guid,@MoPar_guid,getdate(),newid(),@stguidSrc,@rackguid,@BATCH)
				--UPDATE preMergeTemp SET ISFINISH=1 WHERE [mopar_guid]=@MoPar_guid AND BATCH=@BATCH
				END	
				ELSE BEGIN --小号已经做完
					IF EXISTS(SELECT TOP 1 1 FROM tRackInf WHERE GUID<>@rackguid AND dbo.fm_getMoParBySub(ZdOnline_guid)=@MoPar_guid AND ISNULL(batch,0)=@batch AND SEQNO=9999)
					BEGIN--同批次的合并部件已经做完 (小号)
						SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=7  AND IsOver=0  AND Fpcnt=0 AND Outcnt=0
							ORDER BY  nid ASC
						IF( @stguidDes IS NULL)
						BEGIN
							IF NOT EXISTS (SELECT TOP 1 1 FROM #hbStation A LEFT JOIN tRackInf B ON A.Station_guid=B.Station_guid AND A.TrackID=B.TrackID WHERE  B.GUID<>@rackguid AND ISNULL(InStation,0)=0)
							BEGIN --每个合并站都可以分配
								SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=a.Station_guid, @trackDes=a.TrackID 
										FROM @tSt A LEFT JOIN tRackInf B ON A.Station_guid=B.Station_guid AND A.TrackID=B.TrackID   WHERE a.StFunc=7 AND a.IsOver=0 AND B.GUID<>@rackguid AND ISNULL(InStation,0)=0  ORDER BY A.Fpcnt ASC
							END
							IF( @stguidDes IS NULL)
							BEGIN
								SELECT @ID= min(NID) FROM #hbStation
								WHILE @ID IS NOT NULL
								BEGIN						
									SET @BREAK=@ID
									SELECT @hbstaguid=Station_guid,@TrackID=TrackID FROM #hbStation where nid=@ID
											IF(@stguidDes IS NULL)
											BEGIN
												SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM #hbStation where nid=@ID	
											END
										
											BREAK;
										--END
									--END
									--循环结束
									SELECT top 1 @ID=NID FROM #hbStation WHERE nid>@ID order by nid asc;
									IF(@BREAK=@ID)
									BEGIN
										SET @ID = NULL;
									END
								END
							END
						END
					END
					IF(@stguidDes IS NOT NULL)
					BEGIN --小号分配
						INSERT INTO [preMergeTemp]([Station_guid],[part_guid],[mopar_guid],[datetime],[guid],[merge_stid],[RackInf_guid],BATCH)
							VALUES(@stguidDes,@PART_guid,@MoPar_guid,getdate(),newid(),@stguidSrc,@rackguid,@BATCH)						
					END	
					IF(@stguidDes IS  NULL)
					BEGIN --小号不出站 (转)
						--小号储备站里面的衣架
						SELECT ZdOnline_guid,Batch,GUID INTO #cb0RackList FROM tRackInf WHERE Station_guid=@stguidSrc AND InStation=1 --ORDER BY LastTime asc
						
						SELECT ZdOnline_guid,Batch,GUID INTO #finishRackList FROM tRackInf A LEFT JOIN #cb0RackList B ON dbo.fm_getMoParBySub(A.ZdOnline_guid)=dbo.fm_getMoParBySub(B.ZdOnline_guid) AND A.BATCH=B.BATCH
							WHERE A.SEQNO=9999 AND A.Station_guid<>@stguidSrc
						SELECT GUID INTO #TGUID FROM #finishRackList EXCEPT SELECT GUID FROM #cb0RackList
						IF EXISTS(SELECT TOP 1 1 FROM #TGUID )
						BEGIN--转
							SELECT @lineguidDes=@lineguidSrc, @stguidDes=@stguidSrc;			
							RETURN
						END
						ELSE BEGIN--不转
							SELECT @lineguidDes=@lineguidSrc, @stguidDes=@stguidSrc;
						END
					END
				END
			END
			ELSE BEGIN	
				IF(@stguidDes IS NOT NULL)
				BEGIN
					INSERT INTO [preMergeTemp]([Station_guid],[part_guid],[mopar_guid],[datetime],[guid],[merge_stid],[RackInf_guid],BATCH)
						VALUES(@stguidDes,@PART_guid,@MoPar_guid,getdate(),newid(),@stguidSrc,@rackguid,@BATCH)
					--UPDATE preMergeTemp SET ISFINISH=1 WHERE [mopar_guid]=@MoPar_guid AND BATCH=@BATCH
				END	
				ELSE BEGIN--回自己(功能留位： 【如果储备站里面有需要的才回自己（上主轨）不然不让出衣】)		
						--SELECT Mopar_guid=(SELECT TOP 1 Mopar_guid FROM preMergeTemp WHERE Station_guid=A.Station_guid AND ISNULL(ISFINISH,0)=0 AND RackInTime IS NOT NULL ORDER BY RackInTime asc),Batch=(SELECT TOP 1 Batch FROM preMergeTemp WHERE Station_guid=A.Station_guid AND ISNULL(ISFINISH,0)=0 AND RackInTime IS NOT NULL ORDER BY RackInTime asc) INTO #hbRackList  FROM #hbStation A
						SELECT B.ZdOnline_guid,B.Batch INTO #hbRackList FROM #hbStation A LEFT JOIN tRackInf B ON A.Station_guid=B.Station_guid WHERE B.InStation=1 
						SELECT ZdOnline_guid,Batch INTO #cbRackList FROM tRackInf WHERE Station_guid=@stguidSrc AND InStation=1 --ORDER BY LastTime asc
						IF EXISTS(SELECT TOP 1 1 FROM #cbRackList A INNER JOIN #hbRackList B ON dbo.fm_getMoParBySub(A.ZdOnline_guid)=dbo.fm_getMoParBySub(B.ZdOnline_guid) AND A.Batch=B.Batch)
						BEGIN
							SELECT @lineguidDes=@lineguidSrc, @stguidDes=@stguidSrc;			
							RETURN
						END
						ELSE BEGIN --不让出站						
							SELECT @lineguidDes=@lineguidSrc, @stguidDes=@stguidSrc;
							IF EXISTS(SELECT TOP 1 1 FROM tRackInf WHERE Station_guid=@stguidSrc  AND SEQNO=9999 AND InStation=0  AND DATEDIFF (minute,lasttime,getdate()) >1) --线上10分钟梅任何请求
							BEGIN
								RETURN;
							END
							--RETURN
						END
						--SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID 
						--						FROM @tSt 
						--						WHERE StFunc=7 AND IsOver=0 ORDER BY Fpcnt
								
					END	
				END
		END
		ELSE BEGIN----非内循环储备站	
		--END
			--IF(@stguidDes IS  NULL)
			--SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID 
			--						FROM @tSt 
			--						WHERE StFunc=7 AND IsOver=0 					
			IF(@stguidDes IS  NULL) --合并站里面没有同批次配对的衣架
			BEGIN
				IF(@partid<@partmax)
				BEGIN--不是最大的 先找没分配的合并站，再找相同合并策略下不同部件的
					IF EXISTS(SELECT TOP 1 1 FROM tRackInf WHERE GUID<>@rackguid AND dbo.fm_getMoParBySub(ZdOnline_guid)=@MoPar_guid AND ISNULL(batch,0)=@batch AND SEQNO=9999)
					BEGIN--同批次的合并部件已经做完 (小号)
						SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=7  AND IsOver=0  AND Fpcnt=0 AND Outcnt=0
							ORDER BY  nid ASC
						IF( @stguidDes IS NULL)
						BEGIN
							IF NOT EXISTS (SELECT TOP 1 1 FROM #hbStation A LEFT JOIN tRackInf B ON A.Station_guid=B.Station_guid AND A.TrackID=B.TrackID WHERE  B.GUID<>@rackguid AND ISNULL(InStation,0)=0)
							BEGIN --每个合并站都可以分配
								SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=a.Station_guid, @trackDes=a.TrackID 
										FROM @tSt A LEFT JOIN tRackInf B ON A.Station_guid=B.Station_guid AND A.TrackID=B.TrackID   WHERE a.StFunc=7 AND a.IsOver=0 AND B.GUID<>@rackguid AND ISNULL(InStation,0)=0  ORDER BY A.Fpcnt ASC
							END
							IF( @stguidDes IS NULL)
							BEGIN
								SELECT @ID= min(NID) FROM #hbStation
								WHILE @ID IS NOT NULL
								BEGIN						
									SET @BREAK=@ID
									SELECT @hbstaguid=Station_guid,@TrackID=TrackID FROM #hbStation where nid=@ID
									--循环开始  --合并站里面衣架和出去的衣架（有相同批次的）
									--IF NOT EXISTS (SELECT TOP 1 1 FROM tRackInf WHERE Station_guid=@hbstaguid AND TrackID=@TrackID AND GUID<>@rackguid AND ISNULL(InStation,0)=0)
									--BEGIN --没有线上医术
										--IF NOT EXISTS(SELECT TOP 1 1 FROM [preMergeTemp] WHERE [Station_guid]=@hbstaguid AND isnull(ISFINISH,0)=0)
										--BEGIN
											--SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID 
											--FROM @tSt 
											--WHERE StFunc=7 AND IsOver=0 ORDER BY Fpcnt
											IF(@stguidDes IS NULL)
											BEGIN
												SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM #hbStation where nid=@ID	
											END
										
											BREAK;
										--END
									--END
									--循环结束
									SELECT top 1 @ID=NID FROM #hbStation WHERE nid>@ID order by nid asc;
									IF(@BREAK=@ID)
									BEGIN
										SET @ID = NULL;
									END
								END
							END
						END
					END
					IF(@stguidDes IS NOT NULL)
					BEGIN --小号分配
						INSERT INTO [preMergeTemp]([Station_guid],[part_guid],[mopar_guid],[datetime],[guid],[merge_stid],[RackInf_guid],BATCH)
							VALUES(@stguidDes,@PART_guid,@MoPar_guid,getdate(),newid(),@stguidSrc,@rackguid,@BATCH)						
					END	
					IF(@stguidDes IS NULL)
					BEGIN --同批次的合并部件没做完 小号去同工序下的储备站
						SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt 
							WHERE stkind=8 AND StFunc=0  AND IsOver=0; --小号先储存在小号内循环（普通站 内循环） 大号（储备站-内循环）
						IF(@stguidDes IS NULL)--没找到合适的储备站 (主轨上转) 出衣加上轨道号为5的
						BEGIN
							SELECT @stguidDes=NULL, @trackDes=5; 
							RETURN  
						END	
					END					
				END
				ELSE BEGIN--
					--IF EXISTS(SELECT TOP 1 1 FROM tRackInf WHERE dbo.fm_getMoParBySub(ZdOnline_guid)=@MoPar_guid AND ISNULL(batch,0)=@batch AND SEQNO=9999)
					--BEGIN--同批次的合并部件已经做完 且小号已经进站						
					--END
					--IF(@stguidDes IS NOT NULL)
					--BEGIN --大号分配
					--	INSERT INTO [preMergeTemp]([Station_guid],[part_guid],[mopar_guid],[datetime],[guid],[merge_stid],[RackInf_guid],BATCH)
					--		VALUES(@stguidDes,@PART_guid,@MoPar_guid,getdate(),newid(),@stguidSrc,@rackguid,@BATCH)
					--	--UPDATE preMergeTemp SET ISFINISH=1 WHERE [mopar_guid]=@MoPar_guid AND BATCH=@BATCH						
					--END
					IF(@partid=@partmax AND @partid=@partmin)	--单部件合并（后整）
					BEGIN
						SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=7  AND IsOver=0 
					END
					IF(@stguidDes IS NULL)
					BEGIN --大号进储备站
					SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt 
							WHERE stkind=8 AND StFunc=1  AND IsOver=0;
					END
					IF(@stguidDes IS NULL)
					BEGIN --同批次的合并部件没做完 小号去同工序下的储备站 大号主轨转
						SELECT @stguidDes=NULL, @trackDes=5;
						RETURN  
					END	
				END
			END
			ELSE BEGIN
				--SELECT @LastInTime=MAX(RackInTime) FROM [preMergeTemp] WHERE Station_guid=@stguidDes AND ISFINISH=1 --(最后完成的时间)
				--IF(DATEDIFF (second ,@LastInTime,getdate()) >30)
				--BEGIN
					INSERT INTO [preMergeTemp]([Station_guid],[part_guid],[mopar_guid],[datetime],[guid],[merge_stid],[RackInf_guid],BATCH)
					VALUES(@stguidDes,@PART_guid,@MoPar_guid,getdate(),newid(),@stguidSrc,@rackguid,@BATCH)
				--END
				--ELSE BEGIN
				--	SELECT @stguidDes=NULL, @trackDes=5;
				--		RETURN
				----UPDATE preMergeTemp SET ISFINISH=1 WHERE [mopar_guid]=@MoPar_guid AND BATCH=@BATCH
				--END
				
			END
		END
	END	
END
---
IF(@stguidDes IS NULL)
BEGIN
	--print '从普通站中选择'
	IF EXISTS(SELECT TOP 1 1 FROM @tSt WHERE StFunc=0 AND RackCnt<@racklow AND IsOver=0) --AND Line_guid=@lineguidSrc 
	BEGIN
		--print '同条线内优先，有工位站内衣数都<5, <5的依次平均分配';
		SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID 
			FROM @tSt 
			WHERE StFunc=0 AND RackCnt<@racklow AND Line_guid=@lineguidSrc AND IsOver=0
				AND nid>(SELECT TOP 1 nid FROM @tSt WHERE Station_guid=@prestguid);
		IF(@stguidDes IS NULL)
		BEGIN
			SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt 
				WHERE StFunc=0 AND RackCnt<@racklow  AND IsOver=0; --AND Line_guid=@lineguidSrc
		END
	END
END
IF(@stguidDes IS NULL) --
BEGIN
	--print '从同条线内，普通站中选择';
	SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=0 AND IsOver=0 --AND Line_guid=@lineguidSrc
		ORDER BY AssignPct, nid ASC;
END

IF(@stguidDes IS NULL)
BEGIN
	--print '从全能工站中选择'
	IF EXISTS(SELECT TOP 1 1 FROM @tSt WHERE StFunc=2 AND RackCnt<@racklow AND Line_guid=@lineguidSrc AND IsOver=0)
	BEGIN
		--print '同条线内优先，有工位站内衣数都<5, <5的依次平均分配';
		SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID
			FROM @tSt WHERE StFunc=2 AND RackCnt<@racklow AND Line_guid=@lineguidSrc AND IsOver=0
				AND nid>(SELECT TOP 1 nid FROM @tSt WHERE Station_guid=@prestguid);
		IF(@stguidDes IS NULL)
		BEGIN
			SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt
				WHERE StFunc=2 AND RackCnt<@racklow AND Line_guid=@lineguidSrc AND IsOver=0;
		END
	END
	IF(@stguidDes IS NULL)
	BEGIN
		--print '从同条线内全能工站中选择';
		SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=2 AND IsOver=0 AND Line_guid=@lineguidSrc
			ORDER BY AssignPct, nid ASC;
	END
END

IF(@stguidDes IS NULL)
BEGIN
	--print '从其他线普通站中选择'
	SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=0 AND IsOver=0
		ORDER BY AssignPct, nid ASC;
END

IF(@stguidDes IS NULL)
BEGIN
	--print '从其他线全能工站中选择'
	SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=2 AND IsOver=0
		ORDER BY AssignPct, nid ASC;
END

IF(@stguidDes IS NULL)
BEGIN
	--MT要求，自动出衣站的衣架可以进入储备站， 20150403
	--IF(@isauto=1)
	--BEGIN
	--	--print '自动出衣站'
	--	RETURN ;
	--END
	
	--print '从同线内储备站中选择'
	SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=1 AND IsOver=0 AND Line_guid=@lineguidSrc
		ORDER BY AssignPct, nid ASC;
END

IF(@stguidDes IS NULL)
BEGIN
	--print '从其他线储备站中选择'
	SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt WHERE StFunc=1 AND IsOver=0
		ORDER BY AssignPct, nid ASC;
END

IF(@stguidDes IS NULL)
BEGIN
	IF((dbo.fg_GetPara(@lineguidSrc, 'h00000010')=0 AND dbo.fg_GetPara(@lineguidSrc, 'h00200000')=1) OR (@isjoin=1))	--当前站是桥接站
	BEGIN
		--print '参数禁止：下道工序不能进衣时，当前站停止出衣'
		--print '参数允许：下道工序满站时，当前工序出站衣架仍分配目标站点';
		--print '重新从普通站中选择';
		SELECT TOP 1 @lineguidDes=Line_guid, @stguidDes=Station_guid, @trackDes=TrackID FROM @tSt --WHERE StFunc=0 --AND IsOver=0
			ORDER BY StFunc, AssignPct, nid;
	END
END

--需求名称：宝发后道分拣需求
--修改时间：20150518
--修改人：zys
IF(dbo.fg_GetPara(@lineguidSrc, 's10001000')=1)
BEGIN
	--定义存储工作站类型的变量
	DECLARE @seqkind_Src int;	--当前工作站类型
	DECLARE @seqkind_Des int;	--目标工作站类型
	DECLARE @RackCode_OutStation int;	--出站衣架号
	DECLARE	@stguidDes_Fab uniqueidentIFier;	--匹卡目标站唯一标识
	DECLARE @trackDes_Fab tinyint;	--匹卡目标站轨道号
	DECLARE @Fab_MoNo nvarchar(50);	--制单号
	DECLARE @CardNo_Fab int;	--匹卡卡号
	DECLARE @CardNo_Fab_Small int;	--小卡卡号
	DECLARE @CardNo_Fab_Small_Size nvarchar(50);	--小卡尺寸
	DECLARE @HostName_Fab nvarchar(50);	--匹卡对应的客户端名称
	DECLARE @LineId_Fab tinyint;	--匹卡对应的生产线编号
	DECLARE @OnlineCount_Fab int;	--匹卡上线数量
	DECLARE @OnlineCount_Fab_Small int;	--小卡上线数量
	DECLARE @SumCount_Fab int;	--匹卡总数量
	DECLARE @SumCount_Fab_Small int;	--小卡总数量
	DECLARE @Mono_Small nvarchar(50);	--小卡最新制单号

	--获取当前工作站类型
	-----SELECT TOP 1 @seqkind_Src=seqkind FROM tstation WHERE guid=@stguidSrc;
	--获取目标工作站类型
	SELECT TOP 1 @seqkind_Des=seqkind FROM tstation WHERE guid=@stguidDes;
	--获取出站衣架号
	SELECT TOP 1 @RackCode_OutStation=ICCode^0x5aa5aa55 FROM #tRackSrc;
	--判断@stguidSrc是否是QC站？@stguidDes是否是分拣站？
	IF(@seqkind_Des=5)	--如果是从QC站出衣，并且后面一个站是分拣站
		BEGIN
			--关联衣架信息表、货卡信息表、裁片发卡信息表、裁片匹卡发卡信息表、匹卡刷卡信息表
			--获取小卡卡号		
			SELECT @CardNo_Fab_Small=tCutBundCard.CardNo,@Fab_MoNo=tCutBundCard.MONo 
			FROM tRackInf WITH (NOLOCK) left join tBinCardInf WITH (NOLOCK) on tRackInf.BinCardInf_guid=tBinCardInf.guid
			left join tCutBundCard WITH (NOLOCK) on tBinCardInf.CardNo=tCutBundCard.CardNo
			WHERE RackCode=@RackCode_OutStation
			order by tRackInf.InsertTime desc;					--根据衣架信息表的插入时间倒序排列，取最新的记录
			--获取该小卡对应的匹卡的卡号
			SELECT @CardNo_Fab=b.CardNo FROM tCutBundCard b WITH (NOLOCK), (SELECT MONo,CutLotNo,GarPart,OrderNoFabColor FROM tCutBundCard WITH (NOLOCK) WHERE CardNo=@CardNo_Fab_Small and MONo=@Fab_MoNo) a 
			WHERE b.MONo=a.mono and b.CutLotNo=a.CutLotNo and b.GarPart=a.GarPart and b.OrderNoFabColor=a.OrderNoFabColor AND b.CardType=6
			--通过匹卡刷卡信息表获取目标站的站号及轨道号
			SELECT TOP 1 @stguidDes_Fab=tFabCardSwingInfo.Station_guid,@trackDes_Fab=tFabCardSwingInfo.TrackID,		--选择匹卡刷卡信息表的工作站号和轨道号最为此存储过程的输出
			@HostName_Fab=tFabCardSwingInfo.HostName,@LineId_Fab=tFabCardSwingInfo.LineId
			FROM tFabCardSwingInfo WITH (NOLOCK) WHERE tFabCardSwingInfo.CardNo=@CardNo_Fab
			ORDER BY InsertTime DESC;
			--比对分拣站最后刷的匹卡与挂片站刷的小卡是否一致，如果一致，则进行分拣；否则，目标站及目标轨道置空
			IF(@CardNo_Fab=(SELECT TOP 1 CardNo FROM tFabCardSwingInfo WITH (NOLOCK) WHERE HostName=@HostName_Fab and LineId=@LineId_Fab and Station_guid=@stguidDes_Fab order by InsertTime desc))
				BEGIN
				IF(@stguidDes_Fab is not null)						--如果匹卡目标站唯一标识非空
					BEGIN
					IF exists(SELECT TOP 1 1 FROM tSeqAssign WITH (NOLOCK),tStAssign WITH (NOLOCK) WHERE tSeqAssign.guid=tStAssign.SeqAssign_guid and Station_guid=@stguidDes_Fab and Route_guid=@routeid)
						SELECT @stguidDes=@stguidDes_Fab,@trackDes=@trackDes_Fab;	--将目标站唯一标识设置匹卡目标站唯一标识，设置目标站轨道号
					ELSE
						SELECT @stguidDes=NULL,@trackDes=NULL;	--将目标站唯一标识设置匹卡目标站唯一标识，设置目标站轨道号
					END
				ELSE
					SELECT @stguidDes=NULL,@trackDes=NULL;	--将目标站唯一标识设置匹卡目标站唯一标识，设置目标站轨道号
				END
			ELSE
				SELECT @stguidDes=NULL,@trackDes=NULL;	--将目标站唯一标识设置匹卡目标站唯一标识，设置目标站轨道号
		END

	--判断如果是挂片站出站，查询此衣架对应的匹卡信息，更新（或者插入）匹卡发卡信息表
	IF(@seqkind_Src=1)		--如果当前站类型是挂片站
		BEGIN
			
			IF(@CardNo_Fab_Small is not Null)		--判断小卡卡号是否为空
				BEGIN
					--获取小卡最新的制单号
					SELECT TOP 1 @Mono_Small=Mono FROM tCutBundCard WITH(NOLOCK) WHERE CardNo=@CardNo_Fab_Small ORDER BY InsertTime DESC;				
				END
		END
	--对于目标站是分拣站的情况进行处理，需要根据分拣站刷匹牌的情况，决定衣架去哪个分拣站
	IF(@seqkind_Des=5)	--如果是从QC站出衣，并且后面一个站是分拣站
		print '分拣站拒绝再分配'
	ELSE
		BEGIN
		IF(@stguidDes IS NOT NULL)
		BEGIN
			IF (@lineguidSrc <> @lineguidDes) AND (@lineguidSrc = (SELECT TOP 1 b.Line_guid FROM #tRackSrc a, tStation b WITH (NOLOCK) WHERE a.Station_guid_Src=b.guid))
			BEGIN
				--print '当前流水线=衣架起点流水线，当前流水线<>衣架目标流水线, 即跨线'
				IF(dbo.fg_GetPara(@lineguidSrc, 'ToExtLineRackQty') <=
						(SELECT COUNT(*) FROM tRackInf a WITH (NOLOCK), tStation b WITH (NOLOCK), tStation c WITH (NOLOCK)
							WHERE a.Station_guid_Src=b.guid AND b.Line_guid=@lineguidSrc AND a.Station_guid=c.guid AND c.Line_guid<>@lineguidSrc))
				BEGIN
					SELECT @stguidDes=NULL, @trackDes=1;
				END
			END
		END
	END
	
END

--需求名称：安踏风干站需求
--修改人：zys
--修改时间：2015-7-26
DECLARE	@LastTime smalldatetime;		--最后访问衣架时间，精确到秒
DECLARE @rackid uniqueidentIFier;	--衣架号（唯一标识）
IF EXISTS (SELECT TOP 1 1 FROM tstation WHERE guid=@stguidSrc AND seqkind=6)		--如果是风干站，衣物需要在站内停留20分钟之后，才能够允许出站
	BEGIN
		SELECT TOP 1 @rackid=guid FROM #tRackSrc;
		SELECT TOP 1 @LastTime=LastTime FROM tRackInf WITH (NOLOCK) WHERE guid=@rackid ORDER BY LastTime DESC;
		IF(DATEDIFF(SECOND,@LastTime,GETDATE())<=1200)
			SELECT @stguidDes=NULL, @trackDes=1;
	END

	
IF((@stguidSrc=@stguidDes) AND (@outkind<>0))
BEGIN
	--print '回到自己站的，不让其出站'
	SELECT @stguidDes=NULL, @trackDes=1;
END