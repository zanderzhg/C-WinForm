namespace HKMonitor {
    using System;
    using System.Data;
    using System.Data.SqlClient;
    using System.Windows.Forms;
    using System.IO;
    
    public partial class DataSet1 {
        partial class tWorkWLBMDataTable
        {
        }

        private SqlConnection m_conn = new SqlConnection();

        public string videoSer, viedoPort;//视频服务器 端口

        public SqlConnection Connection
        {
            get
            {
                if ((m_conn.ConnectionString != "") && (m_conn.State != ConnectionState.Open))
                {
                    try
                    {
                        m_conn.Open();
                    }
                    catch
                    {
                    }
                }

                return m_conn;
            }
        }

        public void SetConnectStr(string strConn)
        {
            m_conn.Close();
            m_conn.ConnectionString = strConn;
        }

        public bool TestConn(string strConn)
        {
            bool rlt = false;
            SqlConnection conn = new SqlConnection(strConn);
            try
            {
                conn.Open();
                conn.Close();
                rlt = true;
            }
            catch //(System.Exception e)
            {
               // MessageBox.Show("连接数据库失败");
            }
            conn.Dispose();
            return rlt;
        }
        //平板线的登陆操作
        public int PadLoginInfo(int lid, int stid,string mac,int opp)
        {
            int rlt=0 ;
            SqlCommand cmdTmp = new SqlCommand("dbo.pc_PadLoginInfo", Connection);
            cmdTmp.CommandType = CommandType.StoredProcedure;
            cmdTmp.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            cmdTmp.Parameters.Add("@stid", SqlDbType.Int).Value = stid;
            cmdTmp.Parameters.Add("@opp", SqlDbType.Int).Value = opp;
            cmdTmp.Parameters.Add("@mac", SqlDbType.VarChar, 20).Value = mac;
            cmdTmp.Parameters.Add("@rlt", SqlDbType.Int).Direction = ParameterDirection.Output;
            try
            {
                cmdTmp.ExecuteNonQuery();
                rlt =Convert.ToInt32(cmdTmp.Parameters["@rlt"].Value);
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "SeqStartNr");
            }
            cmdTmp.Dispose();
            return rlt;
        }
        //上线的
        public bool GetPadOnInfo(int lid)
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.pc_GetPadOnInfo", Connection);
            adp.SelectCommand.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                PadOnInfo.Clear();
                adp.Fill(PadOnInfo);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetPadOnInfo");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //生成完成的 未分配 
        public bool GetPadFinishInfo(int lid)
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.GetPadFinishInfo", Connection);
            adp.SelectCommand.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                PadFinishInfo.Clear();
                adp.Fill(PadFinishInfo);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetPadFinishInfo");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //准备切割的 注意;(脚本加上 绑定后去掉)
        public bool GetPadReaderData(int lid)
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.GetPadReaderData", Connection);
            adp.SelectCommand.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                PadReaderData.Clear();
                adp.Fill(PadReaderData);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetPadReaderData");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //MES获得工序
        public bool GetSeqData()
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.GetSeqData", Connection);
            //adp.SelectCommand.Parameters.Add("@lid", SqlDbType.NVarChar, 50).Value = lid;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                tseqBase.Clear();
                adp.Fill(tseqBase);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetSeqData");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //批量修改
        public bool SavetStBundSeq()
        {
            bool rlt = false;
            SqlCommand cmdSeq = new SqlCommand(string.Empty, Connection);
            cmdSeq.CommandType = CommandType.Text;
            cmdSeq.Parameters.Add("@guid", SqlDbType.UniqueIdentifier, 16, "guid");
            cmdSeq.Parameters.Add("@SeqName", SqlDbType.NVarChar, 200, "SeqName");//.Value = routeguid;
            cmdSeq.Parameters.Add("@StName", SqlDbType.NVarChar, 200, "StName");

            SqlDataAdapter adp = new SqlDataAdapter();
           // SqlTransaction tx = null;
            try
            {
             //   tx = Connection.BeginTransaction();

                adp.UpdateCommand = cmdSeq;
                cmdSeq.CommandText =
@"UPDATE tStBundSeq SET SeqName=@SeqName, StName=@StName WHERE guid=@guid;";
                adp.Update(tStBundSeq.Select(null, null, DataViewRowState.ModifiedCurrent));

   
              //  tx.Commit();
                tStBundSeq.AcceptChanges();

            }
            catch (Exception ex)
            {
                //if (tx != null)
                //    tx.Rollback();
                MessageBox.Show(ex.Message, "SavetStBundSeq");
            }
            return rlt;
        }
        public bool GetSeqbund()
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter(
                @"SELECT guid, st_guid, lid, sid,SeqName,StName FROM tStBundSeq"
                , Connection);
            adp.SelectCommand.CommandType = CommandType.Text;
            try
            {
                tStBundSeq.Clear();
                adp.Fill(tStBundSeq);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetSeqbund");
            }
            adp.Dispose();
            return rlt;
        }
        public bool GetSeqst()
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter(
                @"select lid=a.lineid,sid=b.stationid from tline a left join tstation b on a.guid=b.line_guid order by lineid,stationid"
                , Connection);
            adp.SelectCommand.CommandType = CommandType.Text;
            try
            {
                tsl.Clear();
                adp.Fill(tsl);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetSeqbund");
            }
            adp.Dispose();
            return rlt;
        }
        public bool Gettline()
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter(
                @"select distinct lid=lineid from tline order by  lineid"
                , Connection);
            adp.SelectCommand.CommandType = CommandType.Text;
            try
            {
                tline.Clear();
                adp.Fill(tline);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "tline");
            }
            adp.Dispose();
            return rlt;
        }
        
        public bool UpdateSeqbund(string seqname, Guid guid)
        {
            bool rlt = false;
            SqlCommand cmd = new SqlCommand(string.Empty, Connection);
            cmd.CommandType = CommandType.Text;
            cmd.CommandText = string.Format(@"Update tStBundSeq SET SeqName='{0}' where guid='{1}'", seqname, guid);
            try
            {
                cmd.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "UpdateSeqbund");
            }
            cmd.Dispose();
            return rlt;
        }
        public bool InsertSeqbund(Int32 lid, Int32 sid, string seqname)
        {
            bool rlt = false;
            SqlCommand cmd = new SqlCommand(string.Empty, Connection);
            cmd.CommandType = CommandType.Text;
            cmd.CommandText = string.Format(@"insert into tStBundSeq (guid,lid,sid,SeqName) values (newid(),{0},{1},'{2}')", lid,sid,seqname);
            try
            {
                cmd.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "InsertSeqbund");
            }
            cmd.Dispose();
            return rlt;
        }
        public bool SysSeqbund()
        {
            bool rlt = false;
            SqlCommand cmd = new SqlCommand(string.Empty, Connection);
            cmd.CommandType = CommandType.Text;
            cmd.CommandText = string.Format(@"select a.guid ,lid=lineid,sid=stationid,StName into #temp
  from tstation a inner join  TLINE B ON A.LINE_GUID=B.GUID order by lid,sid
  update tStBundSeq set st_guid=b.guid,StName=b.StName from tStBundSeq a left join #temp b on a.lid=b.lid and a.[sid]=b.[sid]
  drop table #temp");
            try
            {
                cmd.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "SysSeqbund");
            }
            cmd.Dispose();
            return rlt;
        }
        public bool DelSeqbund(Guid guid)
        {
            bool rlt = false;
            SqlCommand cmd = new SqlCommand(string.Empty, Connection);
            cmd.CommandType = CommandType.Text;
            cmd.CommandText = string.Format(@"delete from tStBundSeq where guid='{0}'", guid);
            try
            {
                cmd.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "DelSeqbund");
            }
            cmd.Dispose();
            return rlt;
        }
        //物流清单
        public bool Gettlogistics(string BarCode) 
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.Gettlogistics", Connection);
            adp.SelectCommand.Parameters.Add("@BarCode", SqlDbType.NVarChar, 20).Value = BarCode;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                tlogistics.Clear();
                adp.Fill(tlogistics);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "Gettlogistics");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //领料清单
        public bool GettLlInf(string pMoNo, string SeqName)
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.pc_getLlInfo", Connection);
            adp.SelectCommand.Parameters.Add("@pMoNo", SqlDbType.NVarChar, 50).Value = pMoNo;
            adp.SelectCommand.Parameters.Add("@SeqName", SqlDbType.NVarChar, 200).Value = SeqName;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                tLlInf.Clear();
                adp.Fill(tLlInf);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GettLlInf");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //视频路径
        public string GetViedoUrl(string pMoNo, string SeqName)
        {
            string url = "";
            SqlCommand cmdTmp = new SqlCommand("dbo.GetViedoUrl", Connection);
            cmdTmp.CommandType = CommandType.StoredProcedure;
            cmdTmp.Parameters.Add("@pMoNo", SqlDbType.NVarChar, 50).Value = pMoNo;
            cmdTmp.Parameters.Add("@SeqName", SqlDbType.NVarChar, 200).Value = SeqName;
            cmdTmp.Parameters.Add("@UrL", SqlDbType.NVarChar, 200).Direction = ParameterDirection.Output;
            try
            {
                cmdTmp.ExecuteNonQuery();
                url = cmdTmp.Parameters["@UrL"].Value.ToString();
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetViedoUrl");
            }
            cmdTmp.Dispose();
            if (url != string.Empty)
            {
                url = "http://" + videoSer + ":" + viedoPort + url;
            }
            return url;
        }
        //绑定条码和芯的工单
        public bool SaveBundInfo(Guid Mo_guid, string BarCode,Int32 lid)
        {
            bool rlt = false;
            SqlCommand adp = new SqlCommand("pm_SaveBundInfo", Connection);
            adp.CommandType = CommandType.StoredProcedure;
            adp.Parameters.Add("@Mo_guid", SqlDbType.UniqueIdentifier).Value = Mo_guid;
            adp.Parameters.Add("@BarCode", SqlDbType.NVarChar, 50).Value = BarCode;
            adp.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            try
            {
                adp.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, ("SaveBundInfo"));
            }
            adp.Dispose();
            return rlt;
        }
        //条码是否存在
        public int isBarCodeExist(string BarCode)
        {
            int cnt = -1;
            SqlCommand cmdTmp = new SqlCommand(string.Empty, Connection);
            cmdTmp.CommandType = CommandType.Text;
            cmdTmp.Parameters.Add("@BarCode", SqlDbType.NVarChar, 50).Value = BarCode;          
            cmdTmp.Parameters.Add("@cnt", SqlDbType.Int).Direction = ParameterDirection.Output;

            cmdTmp.CommandText =
@"SELECT @cnt=COUNT(1) FROM [tCodeBundMoPar] WHERE [BarCode]=@BarCode";
            try
            {
                cmdTmp.ExecuteNonQuery();
                cnt = (int)cmdTmp.Parameters["@cnt"].Value;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "isBarCodeExist");
            }
            cmdTmp.Dispose();

            return cnt;
        }
        //查看绑定信息
        public bool GettBundPart(int lid)
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.GettBundPart", Connection);
            adp.SelectCommand.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                tBundPart.Clear();
                adp.Fill(tBundPart);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GettBundPart");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //修改绑定信息
        public string EditBundInfo(string MONO, string BarCode, Int32 lid)
        {
            string rlt = "";
            SqlCommand adp = new SqlCommand("pm_EditBundInfo", Connection);
            adp.CommandType = CommandType.StoredProcedure;
            adp.Parameters.Add("@MONO", SqlDbType.NVarChar, 50).Value = MONO;
            adp.Parameters.Add("@BarCode", SqlDbType.NVarChar, 50).Value = BarCode;
            adp.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            adp.Parameters.Add("@msg", SqlDbType.NVarChar, 200).Direction = ParameterDirection.Output;
            try
            {
                adp.ExecuteNonQuery();
                rlt = adp.Parameters["@msg"].Value.ToString();
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, ("EditBundInfo"));
            }
            adp.Dispose();
            return rlt;
        }
        //确定绑定顺序
        public bool SetDateTime(string BarCode)
        {
            bool rlt = false;
            SqlCommand adp = new SqlCommand("pm_SetDateTime", Connection);
            adp.CommandType = CommandType.StoredProcedure;
            adp.Parameters.Add("@BarCode", SqlDbType.NVarChar, 50).Value = BarCode;
            try
            {
                adp.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, ("SetDateTime"));
            }
            adp.Dispose();
            return rlt;
        }
        //
        /// <summary>
        /// 查询所有的物料编码信息
        /// </summary>
        /// <param name="hostname"></param>
        /// <param name="lineid"></param>
        /// <param name="stid"></param>
        /// <returns></returns>
        public bool GetWorkWLBM(string hostname, string lineid, string stid)
        {
           bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.pc_GetWorkRackCadeMessage", Connection);
            adp.SelectCommand.Parameters.Add("@hostname", SqlDbType.VarChar).Value = hostname;
            adp.SelectCommand.Parameters.Add("@lineid", SqlDbType.TinyInt).Value = lineid;
            adp.SelectCommand.Parameters.Add("@stid", SqlDbType.TinyInt).Value = stid; 
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {

                tWorkWLBM.Clear();
                adp.Fill(tWorkWLBM);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "pc_GetWorkRackCadeMessage");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //抓取数据
        public bool MesIntoTTM(DateTime date)
        {
            bool rlt = false;
            SqlCommand adp = new SqlCommand("HKMESDataSynByOrderTime", Connection);
            adp.CommandTimeout = 300;
            adp.CommandType = CommandType.StoredProcedure;
            adp.Parameters.Add("@uorder_ordertime", SqlDbType.Date).Value = date;
            try
            {
                adp.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, ("MesIntoTTM"));
            }
            adp.Dispose();
            return rlt;
        }
        //抓取数据
        public bool MesIntoDD(string mono)
        {
            bool rlt = false;
            SqlCommand adp = new SqlCommand("HKMESDataSynByOrderNum", Connection);
            adp.CommandTimeout = 300;
            adp.CommandType = CommandType.StoredProcedure;
            adp.Parameters.Add("@uorder_number", SqlDbType.NVarChar, 100).Value = mono;
            try
            {
                adp.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, ("MesIntoDD"));
            }
            adp.Dispose();
            return rlt;
        }
        //清理当天数据
        public bool ClearDD()
        {
            bool rlt = false;
            SqlCommand adp = new SqlCommand("ClearTodayMESData", Connection);
            adp.CommandType = CommandType.StoredProcedure;
           //adp.Parameters.Add("@uorder_number", SqlDbType.NVarChar, 100).Value = mono;
            try
            {
                adp.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, ("ClearTodayMESData"));
            }
            adp.Dispose();
            return rlt;
        }

        //获取条码
        public bool GetBarCode()
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter(
                @"select distinct BarCode from tCodeBundMoPar WHERE  ISNULL(Isfinished,0)=0 AND [DateTime] IS NOT NULL "
                , Connection);
            adp.SelectCommand.CommandType = CommandType.Text;
            try
            {
                tline.Clear();
                adp.Fill(tBarCode);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GetBarCode");
            }
            adp.Dispose();
            return rlt;
        }
        //获取绑定信息
        public bool GettCodeBundMopar(string BarCode,int RackCode,int lid ,int kind)
        {
            bool rlt = false;
            SqlDataAdapter adp = new SqlDataAdapter("dbo.pm_SchBundInfo", Connection);
            adp.SelectCommand.Parameters.Add("@BarCode", SqlDbType.NVarChar, 200).Value = BarCode;
            adp.SelectCommand.Parameters.Add("@RackCode", SqlDbType.Int).Value = RackCode;
            adp.SelectCommand.Parameters.Add("@lid", SqlDbType.Int).Value = lid;
            adp.SelectCommand.Parameters.Add("@kind", SqlDbType.Int).Value = kind;
            adp.SelectCommand.CommandType = CommandType.StoredProcedure;
            try
            {
                tCodeBundMoPar.Clear();
                adp.Fill(tCodeBundMoPar);
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "GettCodeBundMopar");
            }
            adp.SelectCommand.Dispose();
            adp.Dispose();
            return rlt;
        }
        //标记完成 S
        public bool SetFinish(Guid guid)
        {
            bool rlt = false;
            SqlCommand cmd = new SqlCommand(string.Empty, Connection);
            cmd.CommandType = CommandType.Text;
            cmd.CommandText = string.Format(@"update tCodeBundMoPar set isfinish=1 ,isfinished=1 where guid='{0}'", guid);
            try
            {
                cmd.ExecuteNonQuery();
                rlt = true;
            }
            catch (System.Exception ex)
            {
                MessageBox.Show(ex.Message, "SetFinish");
            }
            cmd.Dispose();
            return rlt;
        }
    }
}
