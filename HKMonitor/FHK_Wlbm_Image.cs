using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Management;
using ThoughtWorks.QRCode.Codec;
using System.IO.Ports;
using System.IO;
using System.Text.RegularExpressions;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using System.Drawing.Imaging;
using HKMonitor.ServiceReference1;

namespace HKMonitor
{
    public partial class FHK_Wlbm_Image : Form
    {
        MESWebserviceSoapClient mesclient = new MESWebserviceSoapClient();
        private string filestr, webUrl, WorkRackCode, strSql;
        private DataSet1 DS = new DataSet1();
        private string lid,stid;  
        private static Globals.CIniIFile iFile;
        DataTable dtOld=new DataTable();

        

        public FHK_Wlbm_Image()
        {
            
            InitializeComponent();
            this.dataGridView1.AutoGenerateColumns = false;
            Init();
            label3.Text = lid + "-" + stid;
        }
        private void Init()
        {
            setDataColumn();
            
            filestr = Globals.CGlobal.inifile;//inifile=路径+\Risun.ini
            iFile = new Globals.CIniIFile(filestr);
            
            lid = iFile.GetString("PADSECTION", "LINE", "0");
            stid = iFile.GetString("PADSECTION", "STATION", "0");
            try
            {

                this.timer1.Interval = (iFile.GetInt("PADSECTION", "RefreshSecWLBM", 3)) * 1000;
                this.trackBar1.Value = (iFile.GetInt("PADSECTION", "RefreshSecWLBM", 5));
                label7.Text = this.trackBar1.Value + "秒";
            }
            catch { } 
            strSql = @"Data Source=" + iFile.GetString("LOCALSERVER", "Server", ".") + ";Initial Catalog=SUNRISE10_CDB;" +
                    "User ID=" + iFile.GetString("LOCALSERVER", "User", "sa") + ";Password=" + iFile.GetString("LOCALSERVER", "Pwd", "");
            DS.SetConnectStr(strSql);
        }
        /// <summary>
        /// 滑动设定刷新时间
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void trackBar1_Scroll(object sender, EventArgs e)
        {
            this.label7.Text = this.trackBar1.Value.ToString() + "秒";
            this.timer1.Enabled = false;
            this.timer1.Interval = this.trackBar1.Value * 1000;
            this.timer1.Enabled = true;
            //保存
            iFile.WriteString("PADSECTION", "RefreshSecWLBM", this.trackBar1.Value.ToString());
        }
        /// <summary>
        /// 时间控件定时任务
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void timer1_Tick(object sender, EventArgs e)
        {
            timer1.Enabled = false;
            GetWLBM();
            this.timer1.Enabled = true;

        }
        void GetWLBM()
        {
            DS.GetWorkWLBM(null, lid, stid);
            if (DS.tWorkWLBM != null&&DS.tWorkWLBM.Rows!=null&&DS.tWorkWLBM.Rows.Count>0)
            {
                if (WorkRackCode!=DS.tWorkWLBM.Rows[0]["workRackCode"].ToString())
                {
                    WorkRackCode = DS.tWorkWLBM.Rows[0]["workRackCode"].ToString();
                    labWorkRackCode.Text = WorkRackCode;
                    dtOld.Rows.Clear();
                    for (int i = 0; i < DS.tWorkWLBM.Rows.Count; i++)
                    {
                        try
                        {
                            DataRow drow = dtOld.NewRow();
                            drow["num"] = i + 1;
                            drow["bom_childrmtnumber"] = DS.tWorkWLBM.Rows[i]["bom_childrmtnumber"];
                            drow["wName"] = DS.tWorkWLBM.Rows[i]["wName"];
                            try
                            {
                                //if (i == 0)
                                //    drow["webUrl"] = @"http://localhost/2.jpg";
                                //else if (i == 1)
                                //    drow["webUrl"] = @"http://localhost/延经阁.png";
                                //else
                                //    drow["webUrl"] = @"http://localhost/welcome.png";
                                drow["webUrl"] = mesclient.INV_Files(DS.tWorkWLBM.Rows[i]["bom_childrmtnumber"].ToString()).Rows[0]["fileUrl"].ToString();
                            }
                            catch { }
                            dtOld.Rows.Add(drow);
                        }
                        catch { }
                    }
                    dataGridView1.DataSource = dtOld;
                }
            }
        }

        void setDataColumn()
        {
            DataColumn dsnum = new DataColumn("num", typeof(string));
            dtOld.Columns.Add(dsnum);
            DataColumn ds = new DataColumn("bom_childrmtnumber", typeof(string));
            dtOld.Columns.Add(ds); 
            DataColumn dswlbm = new DataColumn("wName", typeof(string));
            dtOld.Columns.Add(dswlbm);
            DataColumn dswebUrl = new DataColumn("webUrl", typeof(string));
            dtOld.Columns.Add(dswebUrl);
        }

        private void dataGridView1_SelectionChanged(object sender, EventArgs e)
        {
            try
            {
                DataGridView dgx = sender as DataGridView;
                if (dgx.SelectedRows != null && dgx.SelectedRows.Count > 0 && dgx.SelectedRows[0].Cells[0].Value != null)
                {
                    System.Net.WebRequest webreq = System.Net.WebRequest.Create(dgx.SelectedRows[0].Cells[3].Value.ToString());
                    System.Net.WebResponse webres = webreq.GetResponse();
                    using (System.IO.Stream stream = webres.GetResponseStream())
                    {
                        this.pictureBox1.Image = null;
                        this.pictureBox1.Height = this.panImage.Height-20;
                        this.pictureBox1.Width = this.panImage.Width-20;
                        this.pictureBox1.BackgroundImageLayout = ImageLayout.Zoom; 
                        this.pictureBox1.BackgroundImage = Image.FromStream(stream);
                    }
                }
            }
            catch { }
        }

        private void button1_Click(object sender, EventArgs e)
        {
            this.pictureBox1.Image = pictureBox1.BackgroundImage;
            
        }

        private void button2_Click(object sender, EventArgs e)
        {
            this.pictureBox1.Image = null;
        }
    }
}
