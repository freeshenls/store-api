module ApplicationHelper
	def link_to_remove_fields(name, f, options = {})
	  options[:class] = [options[:class], "remove_fields"].compact.join(" ")
	  
	  # ⚠️ 核心黑魔法：在 onclick 属性里直接写一行原生 JS 
	  # 当点击时，直接向上寻找最近的 <tr> 或者含有控制盒的 <div> 并当场让它从浏览器里消失（display:none）
	  # 顺便把 _destroy 隐藏域的值改成 1，这样点击保存时，后端会自动把它从数据库里抹去！
	  js_code = "var row = this.closest('tr') || this.closest('.fields'); if(row) { row.style.display = 'none'; }; var destroy_input = this.previousElementSibling; if(destroy_input) { destroy_input.value = '1'; }; return false;"
	  
	  f.hidden_field(:_destroy) + link_to(name, '#', class: options[:class], onclick: js_code)
	end
end
