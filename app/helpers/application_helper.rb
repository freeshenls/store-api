module ApplicationHelper
  # ==========================================
  # Design Tokens & Layout Methods
  # ==========================================
  
  # Standard layout page wrapper container
  def container_custom
    "max-w-[1300px] mx-auto px-6"
  end
  
  # Standard content panels and card wrappers
  def panel_card
    "bg-white border border-[#e2e8f0] rounded-[20px] p-6 shadow-sm"
  end
  
  # ==========================================
  # Button Styles
  # ==========================================
  
  # Primary branding CTA button
  def btn_primary
    "inline-flex items-center justify-center bg-[#074277] hover:bg-[#052e54] text-[#f8fafc] py-3 px-7 rounded-[12px] font-['Outfit'] font-bold shadow-lg transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_6px_20px_rgba(7,66,119,0.4)]"
  end
  
  # Secondary outline/border action button
  def btn_secondary
    "inline-flex items-center justify-center border border-[#e2e8f0] bg-white text-[#64748b] py-3 px-7 rounded-[12px] font-['Outfit'] font-bold transition-all duration-300 hover:text-[#0f172a] hover:border-[#0f172a]"
  end
end
