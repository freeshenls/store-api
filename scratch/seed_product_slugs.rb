# scratch/seed_product_slugs.rb
# Run with: bin/rails runner scratch/seed_product_slugs.rb

ActiveRecord::Base.transaction do
  product_cards = Alchemy::Element.where(name: 'product_card').to_a
  puts "Found #{product_cards.count} product cards in the database."

  product_cards.each_with_index do |pc, idx|
    title = pc.value_for('title').to_s.strip
    if title.present?
      slug_val = title.parameterize
      
      # Make sure the slug ingredient is present and updated
      slug_ing = pc.ingredients.find_by(role: 'slug')
      if slug_ing
        slug_ing.update!(value: slug_val)
        puts "Updated ##{idx + 1}: '#{title}' -> slug: '#{slug_val}'"
      else
        pc.ingredients.create!(
          role: 'slug',
          type: 'Alchemy::Ingredients::Text',
          value: slug_val
        )
        puts "Created & updated ##{idx + 1}: '#{title}' -> slug: '#{slug_val}'"
      end
    else
      puts "Skipped ##{idx + 1}: empty title"
    end
  end
  puts "Slug seeding completed successfully!"
end
