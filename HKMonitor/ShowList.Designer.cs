namespace HKMonitor
{
    partial class ShowList
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.Windows.Forms.DataGridViewCellStyle dataGridViewCellStyle1 = new System.Windows.Forms.DataGridViewCellStyle();
            this.dataGridView1 = new System.Windows.Forms.DataGridView();
            this.dataSet1 = new HKMonitor.DataSet1();
            this.tLlInfBindingSource = new System.Windows.Forms.BindingSource(this.components);
            this.wNameDataGridViewTextBoxColumn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.wTypeDataGridViewTextBoxColumn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.lDataGridViewTextBoxColumn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.wDataGridViewTextBoxColumn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.hDataGridViewTextBoxColumn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            ((System.ComponentModel.ISupportInitialize)(this.dataGridView1)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.dataSet1)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.tLlInfBindingSource)).BeginInit();
            this.SuspendLayout();
            // 
            // dataGridView1
            // 
            this.dataGridView1.AllowUserToAddRows = false;
            this.dataGridView1.AutoGenerateColumns = false;
            this.dataGridView1.AutoSizeColumnsMode = System.Windows.Forms.DataGridViewAutoSizeColumnsMode.AllCells;
            this.dataGridView1.AutoSizeRowsMode = System.Windows.Forms.DataGridViewAutoSizeRowsMode.AllCells;
            dataGridViewCellStyle1.Alignment = System.Windows.Forms.DataGridViewContentAlignment.MiddleLeft;
            dataGridViewCellStyle1.BackColor = System.Drawing.SystemColors.Control;
            dataGridViewCellStyle1.Font = new System.Drawing.Font("宋体", 12F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            dataGridViewCellStyle1.ForeColor = System.Drawing.SystemColors.WindowText;
            dataGridViewCellStyle1.SelectionBackColor = System.Drawing.SystemColors.Highlight;
            dataGridViewCellStyle1.SelectionForeColor = System.Drawing.SystemColors.HighlightText;
            dataGridViewCellStyle1.WrapMode = System.Windows.Forms.DataGridViewTriState.True;
            this.dataGridView1.ColumnHeadersDefaultCellStyle = dataGridViewCellStyle1;
            this.dataGridView1.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.dataGridView1.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.wNameDataGridViewTextBoxColumn,
            this.wTypeDataGridViewTextBoxColumn,
            this.lDataGridViewTextBoxColumn,
            this.wDataGridViewTextBoxColumn,
            this.hDataGridViewTextBoxColumn});
            this.dataGridView1.DataSource = this.tLlInfBindingSource;
            this.dataGridView1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.dataGridView1.Location = new System.Drawing.Point(0, 0);
            this.dataGridView1.Name = "dataGridView1";
            this.dataGridView1.ReadOnly = true;
            this.dataGridView1.RowHeadersVisible = false;
            this.dataGridView1.RowTemplate.Height = 23;
            this.dataGridView1.Size = new System.Drawing.Size(535, 340);
            this.dataGridView1.TabIndex = 0;
            // 
            // dataSet1
            // 
            this.dataSet1.DataSetName = "DataSet1";
            this.dataSet1.SchemaSerializationMode = System.Data.SchemaSerializationMode.IncludeSchema;
            // 
            // tLlInfBindingSource
            // 
            this.tLlInfBindingSource.DataMember = "tLlInf";
            this.tLlInfBindingSource.DataSource = this.dataSet1;
            // 
            // wNameDataGridViewTextBoxColumn
            // 
            this.wNameDataGridViewTextBoxColumn.DataPropertyName = "wName";
            this.wNameDataGridViewTextBoxColumn.HeaderText = "物料名称";
            this.wNameDataGridViewTextBoxColumn.Name = "wNameDataGridViewTextBoxColumn";
            this.wNameDataGridViewTextBoxColumn.ReadOnly = true;
            this.wNameDataGridViewTextBoxColumn.Width = 101;
            // 
            // wTypeDataGridViewTextBoxColumn
            // 
            this.wTypeDataGridViewTextBoxColumn.DataPropertyName = "wType";
            this.wTypeDataGridViewTextBoxColumn.HeaderText = "物料类型";
            this.wTypeDataGridViewTextBoxColumn.Name = "wTypeDataGridViewTextBoxColumn";
            this.wTypeDataGridViewTextBoxColumn.ReadOnly = true;
            this.wTypeDataGridViewTextBoxColumn.Width = 101;
            // 
            // lDataGridViewTextBoxColumn
            // 
            this.lDataGridViewTextBoxColumn.DataPropertyName = "L";
            this.lDataGridViewTextBoxColumn.HeaderText = "长";
            this.lDataGridViewTextBoxColumn.Name = "lDataGridViewTextBoxColumn";
            this.lDataGridViewTextBoxColumn.ReadOnly = true;
            this.lDataGridViewTextBoxColumn.Width = 50;
            // 
            // wDataGridViewTextBoxColumn
            // 
            this.wDataGridViewTextBoxColumn.DataPropertyName = "W";
            this.wDataGridViewTextBoxColumn.HeaderText = "宽";
            this.wDataGridViewTextBoxColumn.Name = "wDataGridViewTextBoxColumn";
            this.wDataGridViewTextBoxColumn.ReadOnly = true;
            this.wDataGridViewTextBoxColumn.Width = 50;
            // 
            // hDataGridViewTextBoxColumn
            // 
            this.hDataGridViewTextBoxColumn.DataPropertyName = "H";
            this.hDataGridViewTextBoxColumn.HeaderText = "高";
            this.hDataGridViewTextBoxColumn.Name = "hDataGridViewTextBoxColumn";
            this.hDataGridViewTextBoxColumn.ReadOnly = true;
            this.hDataGridViewTextBoxColumn.Width = 50;
            // 
            // ShowList
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(535, 340);
            this.Controls.Add(this.dataGridView1);
            this.Name = "ShowList";
            this.Text = "ShowList";
            ((System.ComponentModel.ISupportInitialize)(this.dataGridView1)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.dataSet1)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.tLlInfBindingSource)).EndInit();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.DataGridView dataGridView1;
        private System.Windows.Forms.DataGridViewTextBoxColumn wNameDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn wTypeDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn lDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn wDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn hDataGridViewTextBoxColumn;
        private System.Windows.Forms.BindingSource tLlInfBindingSource;
        private DataSet1 dataSet1;
    }
}