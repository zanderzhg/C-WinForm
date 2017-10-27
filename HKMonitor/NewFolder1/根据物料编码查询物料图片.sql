--表tStation新增列，工作读卡器读到的序号
EXEC AddColumn @TblName ='tStation' , @ColumnName ='workrackcode' , @type ='int NULL'
go
----根据线号、站号，修改工作读卡器的序号
IF OBJECT_ID('pc_SaveWorkRfid') IS NULL
	EXEC ('CREATE PROCEDURE pc_SaveWorkRfid as SELECT 1 A')
GO--lineid, stid, iccode
alter PROCEDURE dbo.pc_SaveWorkRfid
@hostname NVARCHAR(50),
@lineid tinyint,
@stid tinyint,
@iccode int,
@msg NVARCHAR(60) OUTPUT,
@rlt int OUTPUT
--WITH ENCRYPTION
AS
SET NOCOUNT ON;
	declare @lineidGuid uniqueidentifier;
	BEGIN TRY 
		select top 1 @lineidGuid=guid from tLine where LineID=@lineid;
		update tStation set workrackcode=@iccode where Line_guid=@lineidGuid and StationID=@stid;
		set @rlt=1; 
		set @msg='修改衣架号完成';
	END TRY 
	BEGIN CATCH
		set @rlt=0; 
		set @msg=error_message();
	END CATCH
go
--根据线号、站号，查询物料编码信息
IF OBJECT_ID('pc_GetWorkRackCadeMessage') IS NULL
	EXEC ('CREATE PROCEDURE pc_GetWorkRackCadeMessage as SELECT 1 A')
GO--lineid, stid, iccode
alter PROCEDURE dbo.pc_GetWorkRackCadeMessage
@hostname nvarchar(50)='HK_1', --
@lineid tinyint,
@stid tinyint 
--WITH ENCRYPTION
AS
SET NOCOUNT ON;
	declare  @Line_Guid uniqueidentifier,
		@tStation_Guid uniqueidentifier,@card_guid uniqueidentifier,@mono nvarchar(100),
		@seqNo int,@MOSeqD_guid uniqueidentifier,@MOSeqM_Guid uniqueidentifier,
		@seqCode nvarchar(100),@cardno int,@routeguid uniqueidentifier,@wLbm nvarchar(50),@rlt int;
	BEGIN TRY 	 
			--流水线GUID
		SELECT TOP 1 @Line_Guid =guid FROM  [tLine] where  LineID=@lineid;
			--工作站的GUID
		SELECT TOP 1 @tStation_Guid=guid,@cardno=workrackcode FROM  [tStation] where Line_guid=@Line_Guid and StationID=@stid;
		select bom_childrmtnumber=rmt_number,wName=rmt_name from Rmaterial;
		if(@cardno is not null)	
			begin
				SELECT TOP 1 @routeguid=Route_guid FROM [tRackInf] WITH(NOLOCK) WHERE  RackCode=@cardno^0x5aa5aa55;
				SELECT top 1 @mono=mono,@wLbm=B.partCode  FROM tRoute a 
					inner join tmom b on a.mom_guid=b.guid 
					inner join HKMES2017.HKmes.dbo.[Rmaterial] c on b.PartCode=c.rmt_number where a.guid=@routeguid;
				
				SELECT  @cardno workRackCode, C.[bom_childrmtnumber], wName=C.[bom_childrmtname] 
					FROM HKMES2017.HKmes.dbo.Worder A   --工单
					LEFT JOIN HKMES2017.HKmes.dbo.RmatVersion B ON A.worder_rmtnumber=B.rmatvs_rmtnumber 
						and B.rmatvs_rmtnumber=@wLbm--版本
					LEFT JOIN HKMES2017.HKmes.dbo.Bom C ON B.rmatvs_wcode=C.bom_parentwcode--bom
					WHERE A.worder_number=@mono AND rmatvs_vsnew=1;    --BPT2-HDW-0002
				--select @cardno workRackCode, bom_childrmtnumber=rmt_number,wName=rmt_name from Rmaterial;
				set @rlt=1;
			end
		else 
			begin
				set @rlt=0;
				--set @msg='未查询到工作卡的序号';
			end
	END TRY
	BEGIN CATCH
		set @rlt=0;
		--set @msg=error_message();
	END CATCH