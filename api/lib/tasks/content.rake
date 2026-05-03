namespace :content do
  desc "Generate cards for a deck CSV in content-pipeline/seeds/<deck>.csv"
  task :generate, [:deck] => :environment do |_t, args|
    deck = args[:deck] || abort("Usage: bin/rails content:generate[greek_starter]")
    ContentPipeline::Orchestrator.new(deck).run
  end

  desc "Show status of generated cards per language"
  task status: :environment do
    Language.includes(words: :card).find_each do |lang|
      total = lang.words.count
      complete = lang.words.joins(:card).where.not(cards: { image_url: nil, audio_url: nil }).count
      puts "#{lang.code} (#{lang.name}): #{complete}/#{total} cards complete"
    end
  end
end
