using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace HKMonitor
{
    public partial class stSeqbund : Form
    {
        private DataSet1 m_dst;
        private Guid myguid;
        public stSeqbund(DataSet1 m_dst)
        {
            InitializeComponent();
            tStBundSeqBindingSource.DataSource = m_dst.tStBundSeq;
            tStBundSeqBindingSource.Sort = "lid";

            dataGridView1.AutoGenerateColumns = false;
            dataGridView1.DataSource = tStBundSeqBindingSource;
            dataGridView1.MergeColumnNames.Add("lidDataGridViewTextBoxColumn");
           // dataGridView1.MergeColumnNames.Add("sidDataGridViewTextBoxColumn");
           // dataGridView1.MergeColumnNames.Add("StName");

            tseqBaseBindingSource.DataSource = m_dst.tseqBase;
            comboBox1.DataSource = tseqBaseBindingSource;

            tlineBindingSource.DataSource = m_dst.tline;
            comboBox2.DataSource = tlineBindingSource;

            tslBindingSource1.DataSource = m_dst.tsl;
            comboBox3.DataSource = tslBindingSource1;

            this.m_dst = m_dst;

        }
        //tongb
        private void button1_Click(object sender, EventArgs e)
        {
            try
            {
                m_dst.SysSeqbund();
                MessageBox.Show("同步成功");
            }
            catch {
                MessageBox.Show("失败");
            }
        }

        private void stSeqbund_Load(object sender, EventArgs e)
        {
            m_dst.GetSeqData();
            m_dst.GetSeqbund();
            m_dst.Gettline();
            m_dst.GetSeqst();
            DataRowView drv = (DataRowView)comboBox2.SelectedItem;
            string gId = drv.Row["lid"].ToString();
            tslBindingSource1.Filter = string.Format("lid='{0}'", gId);

            dataGridView1_CurrentCellChanged(null,null);
        }

        private void dataGridView1_CurrentCellChanged(object sender, EventArgs e)
        {
            if (dataGridView1.SelectedRows.Count > 0)
            {
                DataSet1.tStBundSeqRow ReaderRow = (dataGridView1.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.tStBundSeqRow;
                myguid = ReaderRow.guid;
                //textBox1.Text = ReaderRow.lid.ToString();
                //textBox2.Text = ReaderRow.sid.ToString();
                comboBox1.SelectedItem = ReaderRow.SeqName;
                comboBox1.SelectedValue = ReaderRow.SeqName;
                comboBox2.SelectedItem = ReaderRow.lid;
                comboBox2.SelectedValue = ReaderRow.lid;
                comboBox3.SelectedItem = ReaderRow.sid;
                comboBox3.SelectedValue = ReaderRow.sid;
               // textBox3.Text = ReaderRow.StName;
            }
        }
        //xiug
        private void button2_Click(object sender, EventArgs e)
        {
            if (button2.Text == "修改")
            {
                comboBox1.Enabled = true;
                button2.Text = "保存";
                button1.Enabled = button5.Enabled = button3.Enabled = button4.Enabled = false;
            }
            else {
                if (myguid != Guid.Empty)
                {
                    m_dst.UpdateSeqbund(comboBox1.SelectedValue.ToString(), myguid);
                    MessageBox.Show("修改成功");
                    m_dst.GetSeqbund();
                }
                else { MessageBox.Show("请选择要修改的那一行"); }
                comboBox1.Enabled = false;
                button2.Text = "修改";
                button1.Enabled = button5.Enabled = button3.Enabled = button4.Enabled = true;
            }
        }
        //xinz
        private void button3_Click(object sender, EventArgs e)
        {
            if (button3.Text == "新增")
            {
                //textBox1.ReadOnly = textBox2.ReadOnly = false;
                //textBox1.Text = textBox2.Text = "";
                comboBox1.Enabled = comboBox2.Enabled = comboBox3.Enabled = true;
                comboBox1.Text = comboBox2.Text = comboBox3.Text = "--请选择--";
                button3.Text = "保存";
                button1.Enabled = button2.Enabled = button5.Enabled = button4.Enabled = false;
            }
            else
            {
                Int32 a=0, b=0;
                try
                {
                     a = Convert.ToInt32(comboBox2.SelectedValue);
                     b = Convert.ToInt32(comboBox3.SelectedValue);
                }
                catch { MessageBox.Show("请选择站点工序"); }
                if (a != 0 && b != 0)
                {
                    m_dst.InsertSeqbund(a, b, comboBox1.SelectedValue.ToString());
                    MessageBox.Show("成功");
                    m_dst.GetSeqbund();
                  //  button1_Click(null,null);
                }
               // textBox1.ReadOnly = textBox2.ReadOnly = true;
                comboBox1.Enabled = comboBox2.Enabled = comboBox3.Enabled = false;
                button3.Text = "新增";
                button1.Enabled = button2.Enabled = button5.Enabled = button4.Enabled = true;
            }
        }

        private void textBox1_KeyPress(object sender, KeyPressEventArgs e)
        {
            //if (!(Char.IsNumber(e.KeyChar)) && e.KeyChar != (char)8)
            //{
            //    e.Handled = true;
            //}
            //else { MessageBox.Show("请输入数字"); }
        }

        private void stSeqbund_FormClosing(object sender, FormClosingEventArgs e)
        {
           // this.ParentForm.Close();
        }

        private void comboBox2_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (comboBox2.SelectedItem != null)
            {
                DataRowView drv = (DataRowView)comboBox2.SelectedItem;
                string gId = drv.Row["lid"].ToString();
                tslBindingSource1.Filter = string.Format("lid='{0}'", gId);
            }
        }

        private void textBox1_TextChanged(object sender, EventArgs e)
        {
            if (textBox1.Text != "")
            {
                if (textBox2.Text != "")
                    tStBundSeqBindingSource.Filter = string.Format("lid = '{0}' and sid='{1}'", textBox1.Text, textBox2.Text);
                else
                    tStBundSeqBindingSource.Filter = string.Format("lid = '{0}'", textBox1.Text);
            }
            else
            {
                tStBundSeqBindingSource.Filter = "1=1";
            }
        }

        private void button4_Click(object sender, EventArgs e)
        {
            DialogResult rlt = MessageBox.Show(Globals.CLanguage.GetString("确定要删除当前选中的吗？"),
                        Globals.CLanguage.GetString("提示"),
                         MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question, MessageBoxDefaultButton.Button1);
            if (rlt != DialogResult.Yes)
            {
                return;
            }
            if (myguid != Guid.Empty)
            {
                m_dst.DelSeqbund(myguid);
                MessageBox.Show("删除成功");
                m_dst.GetSeqbund();
            }
            else { MessageBox.Show("请选择要删除的那一行"); }
        }

        private void button5_Click(object sender, EventArgs e)
        {
            if (button5.Text == "批量编辑")
            {
                //this.dataGridView1.ReadOnly = false;
                
                this.dataGridView1.Columns["Column1"].Visible = true;
                this.dataGridView1.Columns["StName"].ReadOnly = false;
                this.dataGridView1.Columns["Column1"].ReadOnly = false;

                button5.Text = "保存";

                button1.Enabled = button2.Enabled = button3.Enabled = button4.Enabled = false;
            }
            else if (button5.Text == "保存")
            {
                m_dst.SavetStBundSeq();
                this.dataGridView1.Columns["Column1"].Visible = false;
                this.dataGridView1.Columns["StName"].ReadOnly = true;
                this.dataGridView1.Columns["Column1"].ReadOnly = true;
                button5.Text = "批量编辑";
                m_dst.GetSeqbund();
                button1.Enabled = button2.Enabled = button3.Enabled = button4.Enabled = true;
            }
        }

        private void textBox3_TextChanged(object sender, EventArgs e)
        {
            if (textBox3.Text != "")
            {
                tStBundSeqBindingSource.Filter = string.Format("StName LIKE '%{0}%'", textBox3.Text);
            }
            else
            {
                tStBundSeqBindingSource.Filter = "1=1";
            }
        }

    }
}
