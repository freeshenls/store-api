# frozen_string_literal: true

class FilterComponent < ViewComponent::Base
  BASE_CLASS = 'filter'.freeze
  CSS_CLASS = "#{BASE_CLASS}__list mt-6".freeze

  attr_reader :filter, :search_params

  def initialize(filter:, search_params:)
    @filter = filter
    @search_params = search_params || {}
  end

  def call
    if filter[:scope] == :price_range_any
      safe_join([filter_list_title, price_inputs].compact)
    else
      safe_join([filter_list_title, filter_list].compact) if filter_list
    end
  end

  private

  def filter_list_title
    content_tag(:h6, title, class: "#{BASE_CLASS}__title text-heading-sm text-black font-semibold mb-4 mt-8") if title
  end

  def price_inputs
    content_tag :div, class: 'flex items-center gap-2 mt-4 font-sans text-sm text-black w-full' do
      min_input_div = content_tag :div, class: 'flex flex-col gap-1 w-[45%]' do
        concat content_tag(:label, 'Min Price', class: 'text-xs text-shade-60 uppercase tracking-wider font-semibold mb-1')
        concat content_tag(:div, class: 'text-input') {
          number_field_tag(
            'search[price_min]',
            search_params[:price_min],
            placeholder: '$ Min',
            min: 0,
            step: '0.01',
            class: 'w-full'
          )
        }
      end

      separator_span = content_tag :span, '-', class: 'text-shade-40 mt-5'

      max_input_div = content_tag :div, class: 'flex flex-col gap-1 w-[45%]' do
        concat content_tag(:label, 'Max Price', class: 'text-xs text-shade-60 uppercase tracking-wider font-semibold mb-1')
        concat content_tag(:div, class: 'text-input') {
          number_field_tag(
            'search[price_max]',
            search_params[:price_max],
            placeholder: '$ Max',
            min: 0,
            step: '0.01',
            class: 'w-full'
          )
        }
      end

      concat min_input_div
      concat separator_span
      concat max_input_div
    end
  end

  def filter_list
    return @filter_list if @filter_list
    return if labels.empty?

    @filter_list = content_tag :ul, class: CSS_CLASS do
      safe_join(labels.map { |name, value| filter_list_item(name: name, value: value) })
    end
  end

  def filter_list_item(name:, value:)
    id = filter_list_item_id(name)

    content_tag(:li, class: 'checkbox-input mb-3') do
      concat check_box_tag(
        "search[#{filter[:scope].to_s}][]",
        value,
        filter_list_item_checked?(value),
        id: id)

      concat label_tag(id, name)
    end
  end

  def filter_list_item_id(name)
    sanitize_to_id("#{filter[:name]}_#{name}")
  end

  def filter_list_item_checked?(value)
    search_params[filter[:scope]]&.include?(value.to_s)
  end

  def title
    filter[:name]
  end

  def labels
    @labels ||= filter[:labels] || filter[:conds].map { |m,c| [m,m] }
  end
end
