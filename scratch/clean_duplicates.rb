# scratch/clean_duplicates.rb
# Run with: bin/rails runner scratch/clean_duplicates.rb

puts "=== Database Cleanup & Slug Repair ==="
puts "Initial Product Count: #{Product.count}"

# Find all products with non-breaking spaces in CPN
dirty_products = Product.where('cpn LIKE ?', "%\u00a0%")
puts "Found #{dirty_products.count} products with trailing/non-breaking spaces in CPN."

deleted_count = 0
repaired_count = 0

dirty_products.each do |dirty_p|
  clean_cpn = dirty_p.cpn.gsub(/[[:space:]\u00a0]+/, ' ').strip
  clean_p = Product.find_by(cpn: clean_cpn)
  
  if clean_p
    # Delete the dirty duplicate product
    puts "Deleting dirty duplicate: ID #{dirty_p.id}, CPN: #{dirty_p.cpn.inspect}, Slug: #{dirty_p.slug.inspect}"
    dirty_p.destroy
    deleted_count += 1
    
    # Repair the clean product's slug
    old_slug = clean_p.slug
    clean_p.slug = nil # force regeneration
    if clean_p.save
      puts "  -> Repaired clean product: ID #{clean_p.id}, CPN: #{clean_p.cpn.inspect}"
      puts "     Old Slug: #{old_slug.inspect} -> New Slug: #{clean_p.slug.inspect}"
      repaired_count += 1
    else
      puts "  ❌ Error saving repaired product #{clean_p.id}: #{clean_p.errors.full_messages.join(', ')}"
    end
  else
    # No clean counterpart exists, just clean this one in place
    puts "No clean counterpart found for #{dirty_p.cpn.inspect}. Cleaning in place..."
    dirty_p.cpn = clean_cpn
    dirty_p.slug = nil # force regeneration
    if dirty_p.save
      puts "  -> Cleaned in-place: ID #{dirty_p.id}, CPN: #{dirty_p.cpn.inspect}, Slug: #{dirty_p.slug.inspect}"
      repaired_count += 1
    else
      puts "  ❌ Error saving in-place product #{dirty_p.id}: #{dirty_p.errors.full_messages.join(', ')}"
    end
  end
end

puts "\n=== Cleanup Summary ==="
puts "Deleted duplicates: #{deleted_count}"
puts "Repaired slugs: #{repaired_count}"
puts "Final Product Count: #{Product.count} (Expected: 685)"
puts "Remaining dirty CPNs: #{Product.where('cpn LIKE ?', '%\u00a0%').count}"
