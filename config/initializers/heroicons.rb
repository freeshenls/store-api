Heroicons.configure do |config|
  config.variant = :solid # Options are :solid, :outline, :mini, and :micro

  config.default_class = {
    solid: "size-5 inline-block align-middle",
    outline: "size-5 inline-block align-middle",
    mini: "size-4 inline-block align-middle",
    micro: "size-[14px] inline-block align-middle"
  }
end

ActiveSupport.on_load(:view_component) do
  include Heroicons::Helper
  
  # Dynamically delegate all helper methods defined in ApplicationHelper to the helpers proxy
  # This eliminates the need for developers to manually register new helpers
  if defined?(ApplicationHelper)
    ApplicationHelper.instance_methods(false).each do |method|
      delegate method, to: :helpers
    end
  end
end


