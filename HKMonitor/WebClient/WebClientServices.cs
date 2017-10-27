using System.IO;

using System.Net;

using System.CodeDom;

using System.CodeDom.Compiler;

using System.Web.Services;

using System.Web.Services.Description;

using System.Web.Services.Protocols;

using System.Xml.Serialization;
using System.Reflection;
using System;
using System.Data;
using System.Xml;
using Microsoft.CSharp;
using System.Collections;
using System.Text;

namespace HKMonitor
{
    public class WebClientServices
    {
        /// <summary>
        ///根据物料编码和URL地址获取图片Url
        /// </summary>
        /// <param name="wlbm"></param>
        /// <param name="weburl"></param>
        /// <returns></returns>
        public static string getWebUrl(string wlbm, string weburl)
        {
            DataSet ds = InvokeWebService(weburl, new string[] { wlbm});
            if (ds != null && ds.Tables != null && ds.Tables.Count > 0 && ds.Tables[0] != null && ds.Tables[0].Rows != null && ds.Tables[0].Rows.Count > 0)
            { return ds.Tables[0].Rows[0]["fileUrl"].ToString(); }
            else
            {
                return "";
            }
        }
        #region 动态调用WebService动态调用地址
        
       /// <summary>
       /// 动态调用web服务
       /// </summary>
        /// <param name="url">WSDL服务地址</param>
       /// <param name="classname">服务接口类名</param>
        /// <param name="methodname">方法名</param>
       /// <param name="args">参数值</param>
       /// <returns></returns>
        public static DataSet InvokeWebService(string url, object[] args)
        {
            string classname="";
            string @namespace = "WebService1.MES";
            if ((classname == null) || (classname == ""))
            {
                classname = GetWsClassName(url);
            }
            try
            {
                     
                //获取WSDL   
                WebClient wc = new WebClient();
                Stream stream = wc.OpenRead(url + "?WSDL");
                ServiceDescription sd = ServiceDescription.Read(stream);
                //注意classname一定要赋值获取 
                 classname = sd.Services[0].Name; 
              
                ServiceDescriptionImporter sdi = new ServiceDescriptionImporter();
                sdi.AddServiceDescription(sd, "", "");
                CodeNamespace cn = new CodeNamespace(@namespace);

                //生成客户端代理类代码          
                CodeCompileUnit ccu = new CodeCompileUnit();
                ccu.Namespaces.Add(cn);
                sdi.Import(cn, ccu);
                CSharpCodeProvider icc = new CSharpCodeProvider();
                

                //设定编译参数                 
                CompilerParameters cplist = new CompilerParameters();
                cplist.GenerateExecutable = false;
                cplist.GenerateInMemory = true;
                cplist.ReferencedAssemblies.Add("System.dll");
                cplist.ReferencedAssemblies.Add("System.XML.dll");
                cplist.ReferencedAssemblies.Add("System.Web.Services.dll");
                cplist.ReferencedAssemblies.Add("System.Data.dll");
                //编译代理类                 
                CompilerResults cr = icc.CompileAssemblyFromDom(cplist, ccu);
                if (true == cr.Errors.HasErrors)
                {
                    System.Text.StringBuilder sb = new System.Text.StringBuilder();
                    foreach (System.CodeDom.Compiler.CompilerError ce in cr.Errors)
                    {
                        sb.Append(ce.ToString());
                        sb.Append(System.Environment.NewLine);
                    }
                    throw new Exception(sb.ToString());
                }
                //生成代理实例，并调用方法                 
                System.Reflection.Assembly assembly = cr.CompiledAssembly;
                Type t = assembly.GetType(@namespace + "." + classname, true, true);
                object obj = Activator.CreateInstance(t);
                System.Reflection.MethodInfo mi = t.GetMethod("INV_Files");
                return ConvertXMLFileToDataSet(mi.Invoke(obj, args).ToString());
               
            }
            catch (Exception ex)
            {
                throw new Exception(ex.InnerException.Message, new Exception(ex.InnerException.StackTrace));
               // return "Error:WebService调用错误！" + ex.Message;
            }
        }
        private static string GetWsClassName(string wsUrl)
        {
            string[] parts = wsUrl.Split('/');
            string[] pps = parts[parts.Length - 1].Split('.');
            return pps[0];
        }
        #endregion
    
        public static DataSet ConvertXMLFileToDataSet(string xmlFile)
        {
            StringReader stream = null;
            XmlTextReader reader = null;
            try
            {
                XmlDocument xmld = new XmlDocument();
                xmld.Load(xmlFile);

                DataSet xmlDS = new DataSet();
                stream = new StringReader(xmld.InnerXml);
                //从stream装载到XmlTextReader  
                reader = new XmlTextReader(stream);
                xmlDS.ReadXml(reader);
                //xmlDS.ReadXml(xmlFile);  
                return xmlDS;
            }
            catch (System.Exception ex)
            {
                throw ex;
            }
            finally
            {
                if (reader != null) reader.Close();
            }
        }  
    }
    /// <summary>
  /// 利用WebRequest/WebResponse进行WebService调用的类
  /// </summary>
  public class WebServiceCaller
  {
    #region Tip:使用说明
    //webServices 应该支持Get和Post调用，在web.config应该增加以下代码
    //<webServices>
    // <protocols>
    //  <add name="HttpGet"/>
    //  <add name="HttpPost"/>
    // </protocols>
    //</webServices>
  
    //调用示例：
    //Hashtable ht = new Hashtable(); //Hashtable 为webservice所需要的参数集
    //ht.Add("str", "test");
    //ht.Add("b", "true");
    //XmlDocument xx = WebSvcCaller.QuerySoapWebService("http://localhost:81/service.asmx", "HelloWorld", ht);
    //MessageBox.Show(xx.OuterXml);
    #endregion
  
    /// <summary>
    /// 需要WebService支持Post调用
    /// </summary>
    public static XmlDocument QueryPostWebService(String URL, String MethodName, Hashtable Pars)
    {
      HttpWebRequest request = (HttpWebRequest)HttpWebRequest.Create(URL + "/" + MethodName);
      request.Method = "POST";
      request.ContentType = "application/x-www-form-urlencoded";
      SetWebRequest(request);
      byte[] data = EncodePars(Pars);
      WriteRequestData(request, data);
      return ReadXmlResponse(request.GetResponse());
    }
  
    /// <summary>
    /// 需要WebService支持Get调用
    /// </summary>
    public static XmlDocument QueryGetWebService(String URL, String MethodName, Hashtable Pars)
    {
      HttpWebRequest request = (HttpWebRequest)HttpWebRequest.Create(URL + "/" + MethodName + "?" + ParsToString(Pars));
      request.Method = "GET";
      request.ContentType = "application/x-www-form-urlencoded";
      SetWebRequest(request);
      return ReadXmlResponse(request.GetResponse());
    }
  
    /// <summary>
    /// 通用WebService调用(Soap),参数Pars为String类型的参数名、参数值
    /// </summary>
    public static XmlDocument QuerySoapWebService(String URL, String MethodName, Hashtable Pars)
    {
      if (_xmlNamespaces.ContainsKey(URL))
      {
        return QuerySoapWebService(URL, MethodName, Pars, _xmlNamespaces[URL].ToString());
      }
      else
      {
        return QuerySoapWebService(URL, MethodName, Pars, GetNamespace(URL));
      }
    }
  
    private static XmlDocument QuerySoapWebService(String URL, String MethodName, Hashtable Pars, string XmlNs)
    {
      _xmlNamespaces[URL] = XmlNs;//加入缓存，提高效率
      HttpWebRequest request = (HttpWebRequest)HttpWebRequest.Create(URL);
      request.Method = "POST";
      request.ContentType = "text/xml; charset=utf-8";
      request.Headers.Add("SOAPAction", "\"" + XmlNs + (XmlNs.EndsWith("/") ? "" : "/") + MethodName + "\"");
      SetWebRequest(request);
      byte[] data = EncodeParsToSoap(Pars, XmlNs, MethodName);
      WriteRequestData(request, data);
      XmlDocument doc = new XmlDocument(), doc2 = new XmlDocument();
      doc = ReadXmlResponse(request.GetResponse());
  
      XmlNamespaceManager mgr = new XmlNamespaceManager(doc.NameTable);
      mgr.AddNamespace("soap", "http://schemas.xmlsoap.org/soap/envelope/");
      String RetXml = doc.SelectSingleNode("//soap:Body/*/*", mgr).InnerXml;
      doc2.LoadXml("<root>" + RetXml + "</root>");
      AddDelaration(doc2);
      return doc2;
    }
    private static string GetNamespace(String URL)
    {
      HttpWebRequest request = (HttpWebRequest)WebRequest.Create(URL + "?WSDL");
      SetWebRequest(request);
      WebResponse response = request.GetResponse();
      StreamReader sr = new StreamReader(response.GetResponseStream(), Encoding.UTF8);
      XmlDocument doc = new XmlDocument();
      doc.LoadXml(sr.ReadToEnd());
      sr.Close();
      return doc.SelectSingleNode("//@targetNamespace").Value;
    }
  
    private static byte[] EncodeParsToSoap(Hashtable Pars, String XmlNs, String MethodName)
    {
      XmlDocument doc = new XmlDocument();
      doc.LoadXml("<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"></soap:Envelope>");
      AddDelaration(doc);
      //XmlElement soapBody = doc.createElement_x_x("soap", "Body", "http://schemas.xmlsoap.org/soap/envelope/");
      XmlElement soapBody = doc.CreateElement("soap", "Body", "http://schemas.xmlsoap.org/soap/envelope/");
      //XmlElement soapMethod = doc.createElement_x_x(MethodName);
      XmlElement soapMethod = doc.CreateElement(MethodName);
      soapMethod.SetAttribute("xmlns", XmlNs);
      foreach (string k in Pars.Keys)
      {
        //XmlElement soapPar = doc.createElement_x_x(k);
        XmlElement soapPar = doc.CreateElement(k);
        soapPar.InnerXml = ObjectToSoapXml(Pars[k]);
        soapMethod.AppendChild(soapPar);
      }
      soapBody.AppendChild(soapMethod);
      doc.DocumentElement.AppendChild(soapBody);
      return Encoding.UTF8.GetBytes(doc.OuterXml);
    }
    private static string ObjectToSoapXml(object o)
    {
      XmlSerializer mySerializer = new XmlSerializer(o.GetType());
      MemoryStream ms = new MemoryStream();
      mySerializer.Serialize(ms, o);
      XmlDocument doc = new XmlDocument();
      doc.LoadXml(Encoding.UTF8.GetString(ms.ToArray()));
      if (doc.DocumentElement != null)
      {
        return doc.DocumentElement.InnerXml;
      }
      else
      {
        return o.ToString();
      }
    }
  
    /// <summary>
    /// 设置凭证与超时时间
    /// </summary>
    /// <param name="request"></param>
    private static void SetWebRequest(HttpWebRequest request)
    {
      request.Credentials = CredentialCache.DefaultCredentials;
      request.Timeout = 10000;
    }
  
    private static void WriteRequestData(HttpWebRequest request, byte[] data)
    {
      request.ContentLength = data.Length;
      Stream writer = request.GetRequestStream();
      writer.Write(data, 0, data.Length);
      writer.Close();
    }
  
    private static byte[] EncodePars(Hashtable Pars)
    {
      return Encoding.UTF8.GetBytes(ParsToString(Pars));
    }
  
    private static String ParsToString(Hashtable Pars)
    {
      StringBuilder sb = new StringBuilder();
      foreach (string k in Pars.Keys)
      {
        if (sb.Length > 0)
        {
          sb.Append("&");
        }
        //sb.Append(HttpUtility.UrlEncode(k) + "=" + HttpUtility.UrlEncode(Pars[k].ToString()));
      }
      return sb.ToString();
    }
  
    private static XmlDocument ReadXmlResponse(WebResponse response)
    {
      StreamReader sr = new StreamReader(response.GetResponseStream(), Encoding.UTF8);
      String retXml = sr.ReadToEnd();
      sr.Close();
      XmlDocument doc = new XmlDocument();
      doc.LoadXml(retXml);
      return doc;
    }
  
    private static void AddDelaration(XmlDocument doc)
    {
      XmlDeclaration decl = doc.CreateXmlDeclaration("1.0", "utf-8", null);
      doc.InsertBefore(decl, doc.DocumentElement);
    }
  
    private static Hashtable _xmlNamespaces = new Hashtable();//缓存xmlNamespace，避免重复调用GetNamespace
  }
}