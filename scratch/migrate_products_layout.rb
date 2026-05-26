# scratch/migrate_products_layout.rb
# Run with: bin/rails runner scratch/migrate_products_layout.rb

ActiveRecord::Base.transaction do
  # 1. Find the products page (Page ID 2 or name 'products')
  products_page = Alchemy::Page.find_by(id: 2) || Alchemy::Page.find_by(name: 'products')
  unless products_page
    puts "Error: Products page not found!"
    exit 1
  end

  puts "Found products page (ID: #{products_page.id}, Name: '#{products_page.name}')"

  # 2. Update page layout to 'products'
  products_page.update!(page_layout: 'products')
  puts "Successfully changed page layout to 'products'"

  # 3. Clear existing elements on Page 2 draft version to start fresh
  draft_version_p2 = products_page.draft_version
  unless draft_version_p2
    draft_version_p2 = products_page.versions.create!
  end

  old_elements_count = draft_version_p2.elements.count
  draft_version_p2.elements.destroy_all
  puts "Cleared #{old_elements_count} existing elements from page 2's draft version"

  # 4. Fetch all product cards from Page 1 (homepage) draft version
  index_page = Alchemy::Page.find_by(page_layout: 'index') || Alchemy::Page.find_by(id: 1)
  unless index_page
    puts "Error: Index page not found!"
    exit 1
  end

  draft_version_p1 = index_page.draft_version
  unless draft_version_p1
    puts "Error: Homepage has no draft version!"
    exit 1
  end

  product_cards = draft_version_p1.elements.where(name: 'product_card').order(:position).to_a
  puts "Found #{product_cards.count} product cards on index page draft version"

  # 5. Duplicate product cards onto Page 2 draft version
  product_cards.each_with_index do |pc, idx|
    new_el = Alchemy::Element.create!(
      name: pc.name,
      page_version: draft_version_p2,
      position: idx + 1,
      folded: pc.folded,
      unique: pc.unique,
      fixed: pc.fixed,
      public_on: Time.current
    )

    # Update pre-created ingredients or create missing ones
    pc.ingredients.each do |ingredient|
      new_ingredient = new_el.ingredients.find_by(role: ingredient.role)
      if new_ingredient
        new_ingredient.update!(
          value: ingredient.value,
          data: ingredient.data,
          related_object_id: ingredient.related_object_id,
          related_object_type: ingredient.related_object_type
        )
      else
        new_el.ingredients.create!(
          role: ingredient.role,
          type: ingredient.type,
          value: ingredient.value,
          data: ingredient.data,
          related_object_id: ingredient.related_object_id,
          related_object_type: ingredient.related_object_type
        )
      end
    end

    puts "Copied product card ##{idx + 1}: '#{pc.value_for('title')}' (Category: '#{pc.value_for('category')}')"
  end

  puts "Migration completed successfully! Total elements copied: #{product_cards.count}."
end
