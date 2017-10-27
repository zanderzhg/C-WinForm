using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Text.RegularExpressions;

namespace HKMonitor
{
    public partial class MESConfig : Form
    {
        private DataSet1 m_dst;
        public MESConfig(DataSet1 m_dst)
        {
            InitializeComponent();
            tCodeBundMoParBindingSource.DataSource = m_dst.tCodeBundMoPar;
            tCodeBundMoParBindingSource.Sort = "id";
            dataGridView1.DataSource = tCodeBundMoParBindingSource;

            tBarCodeBindingSource.DataSource = m_dst.tBarCode;
            comboBox3.DataSource = tBarCodeBindingSource;

            this.m_dst = m_dst;
        }

        private void monthCalendar1_DateChanged(object sender, DateRangeEventArgs e)
        {

        }

        private void comboBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (comboBox1.SelectedIndex == 0)
            {
                label2.Text = "单号：";
            }
            else if (comboBox1.SelectedIndex == 1)
            {
                label2.Text = "日期：";
            }
        }

        private void button4_Click(object sender, EventArgs e)
        {
            if (MessageBox.Show(
                       "确定删除今天导入的制单么！！！"
                        , "提示"
                        , MessageBoxButtons.OKCancel
                        , MessageBoxIcon.Question
                        , MessageBoxDefaultButton.Button1) == DialogResult.OK)
            {
                m_dst.ClearDD();
            }
           
        }

        private void button1_Click(object sender, EventArgs e)
        {
            this.Cursor = Cursors.WaitCursor;//等待 
            if (textBox1.Text != string.Empty)
            {
                //loadingPanel1.Visible = true;
                //loadingPanel1.LoadingText = "正在抓取...";
                if (label2.Text == "单号：")
                {                
                    if(m_dst.MesIntoDD(textBox1.Text))
                    {                       
                        MessageBox.Show("导入成功");
                        //loadingPanel1.Visible = false;
                        this.Cursor = Cursors.Default;
                    }
                }
                else if (label2.Text == "日期：")
                {
                    if (ValidateDataTime(textBox1.Text))
                    {                       
                        if (m_dst.MesIntoTTM(Convert.ToDateTime(textBox1.Text)))
                        {                     
                            MessageBox.Show("导入成功");
                           // loadingPanel1.Visible = false;
                            this.Cursor = Cursors.Default;
                        }
                    }
                    else { MessageBox.Show("请输入如期格式 yyyy-mm-dd");
                    textBox1.Text = "";
                    textBox1.Focus();
                    this.Cursor = Cursors.Default;
                    }
                }
            }
            else { MessageBox.Show("请输入单号或日期");
            this.Cursor = Cursors.Default;
            }
        }

        public static bool ValidateDataTime(string InputStr)
        {
            if (InputStr.Length > 0)
            {
                if (Regex.IsMatch(InputStr.Trim(), @"^((((1[6-9]|[2-9]\d)\d{2})-(0?[13578]|1[02])-(0?[1-9]|[12]\d|3[01]))|(((1[6-9]|[2-9]\d)\d{2})-(0?[13456789]|1[012])-(0?[1-9]|[12]\d|30))|(((1[6-9]|[2-9]\d)\d{2})-0?2-(0?[1-9]|1\d|2[0-8]))|(((1[6-9]|[2-9]\d)(0[48]|[2468][048]|[13579][26])|((16|[2468][048]|[3579][26])00))-0?2-29-))$"))
                {
                    return true;
                }
                else
                {
                    return false;
                }

            }
            return false;
        }

        private void button3_Click(object sender, EventArgs e)
        {
            new stSeqbund(m_dst).Show();
        }

        private void button6_Click(object sender, EventArgs e)
        {
            
            int rackcode;
            int kind;
            int lid;
            string barcode;
            if (comboBox2.Text != string.Empty)
                kind = comboBox2.SelectedIndex + 1;
            else kind = 0;
            if (comboBox3.Text != string.Empty)
                barcode = comboBox3.Text;//.SelectedValue.ToString();
            else barcode = string.Empty;
              if (textBox2.Text != string.Empty)
            {
                try
                {
                    lid = Convert.ToInt32(textBox2.Text);
                }
                catch
                {
                    MessageBox.Show("线号输入不合法");
                    lid = 0;
                }
            }
            else { lid = 0; }
            if (textBox3.Text != string.Empty)
            {
                try
                {
                    rackcode = Convert.ToInt32(textBox3.Text);
                }
                catch
                {
                    MessageBox.Show("衣架号输入不合法");
                    rackcode = 0;
                }
            }
            else { rackcode = 0; }
            m_dst.GettCodeBundMopar(barcode, rackcode, lid, kind);
           
            
        }

        private void button5_Click(object sender, EventArgs e)
        {
            if (dataGridView1.Rows.Count > 0)
            {
                DataSet1.tCodeBundMoParRow ReaderRow = (dataGridView1.Rows[0].DataBoundItem as DataRowView).Row as DataSet1.tCodeBundMoParRow;
                if (ReaderRow.guid != Guid.Empty)
                {
                    if (m_dst.SetFinish(ReaderRow.guid))
                    {
                        MessageBox.Show("修改成功");
                        button6_Click(null,null);
                    }
                }
                
            }
        }

        private void MESConfig_Load(object sender, EventArgs e)
        {
            m_dst.GetBarCode();
            comboBox3.Text = string.Empty;
        } 
    }
}
