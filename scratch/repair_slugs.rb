# scratch/repair_slugs.rb
# Run with: bin/rails runner scratch/repair_slugs.rb

puts "=== Slug Repair Session ==="
random_slugs = Product.where('slug ~ ?', '-[0-9a-f]{6}$')
puts "Found #{random_slugs.count} products with randomized slugs."

success_count = 0
failed_count = 0

random_slugs.each do |p|
  clean_slug = p.title.parameterize
  
  # Check if there is another product with this clean slug
  existing = Product.where(slug: clean_slug).where.not(id: p.id).first
  if existing
    puts "⚠️ Cannot clean ID #{p.id} (#{p.title.inspect}): clean slug #{clean_slug.inspect} is already taken by ID #{existing.id} (CPN: #{existing.cpn})"
    failed_count += 1
  else
    old_slug = p.slug
    p.slug = clean_slug
    if p.save
      puts "✅ Repaired ID #{p.id} (CPN: #{p.cpn}): #{old_slug.inspect} -> #{clean_slug.inspect}"
      success_count += 1
    else
      puts "❌ Failed to repair ID #{p.id}: #{p.errors.full_messages.join(', ')}"
      failed_count += 1
    end
  end
end

puts "=========================="
puts "Repaired: #{success_count}"
puts "Failed/Skipped: #{failed_count}"
puts "Current Total Product Count: #{Product.count}"
