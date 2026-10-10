class_name ResumeImport
extends RefCounted

const MAX_BYTES := 2*1024*1024
const MAX_TEXT := 12000

static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>MAX_BYTES: return {"error":"无法读取文件，或文件超过2MB。"}
	var bytes := file.get_buffer(file.get_length());file.close()
	var extension := path.get_extension().to_lower()
	var text := ""
	if extension in ["txt","md"]: text=bytes.get_string_from_utf8()
	elif extension=="docx":
		# Check central-directory sizes before ZIPReader allocates decompressed XML.
		if not bounded_docx(bytes): return {"error":"DOCX结构不支持或解压内容过大，请粘贴简历文字。"}
		var archive := ZIPReader.new()
		if archive.open(path)!=OK: return {"error":"无法打开DOCX。"}
		var xml := XMLParser.new()
		var source := archive.read_file("word/document.xml");archive.close()
		if xml.open_buffer(source)!=OK: return {"error":"无法解析DOCX正文。"}
		var inside_text := false
		while xml.read()==OK:
			if xml.get_node_type()==XMLParser.NODE_ELEMENT:
				inside_text=xml.get_node_name()=="w:t"
			elif xml.get_node_type()==XMLParser.NODE_TEXT and inside_text: text+=xml.get_node_data()
			elif xml.get_node_type()==XMLParser.NODE_ELEMENT_END:
				if xml.get_node_name()=="w:p": text+="\n"
				inside_text=false
			if text.length()>MAX_TEXT: break
	else: return {"error":"支持TXT、Markdown和DOCX；PDF请复制文字粘贴到预览框。"}
	text=text.strip_edges()
	if text.length()<30: return {"error":"有效正文不足30字。扫描件或图片简历请先转成文字。"}
	if text.length()>MAX_TEXT: return {"error":"简历超过12000字，请删去无关内容后再导入。"}
	return {"text":text}

static func bounded_docx(bytes: PackedByteArray) -> bool:
	var end := -1
	for at in range(bytes.size()-22,maxi(-1,bytes.size()-65558),-1):
		if bytes.decode_u32(at)==0x06054b50: end=at;break
	if end<0 or bytes.decode_u16(end+4)!=0 or bytes.decode_u16(end+6)!=0: return false
	var count := bytes.decode_u16(end+10)
	var at := int(bytes.decode_u32(end+16))
	if count<1 or count>256 or at<0 or at>=end: return false
	var total := 0
	var found := false
	for i in range(count):
		if at+46>end or bytes.decode_u32(at)!=0x02014b50: return false
		var length := bytes.decode_u16(at+28)
		var next := at+46+length+bytes.decode_u16(at+30)+bytes.decode_u16(at+32)
		if next>end: return false
		var size := int(bytes.decode_u32(at+24));total+=size
		if total>16*1024*1024: return false
		if bytes.slice(at+46,at+46+length).get_string_from_utf8()=="word/document.xml":
			if found or size>256*1024 or bytes.decode_u16(at+8)&1: return false
			found=true
		at=next
	return found
