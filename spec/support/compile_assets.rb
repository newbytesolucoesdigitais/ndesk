# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

RSpec.configure do |config|
  config.before :suite do
    if !Rails.env.development? && !ENV['CI_SKIP_ASSETS_PRECOMPILE']
      puts 'Making sure assets are up-to-date...'
      Rake::Task['assets:precompile'].execute

      # NDESK-60: with `config.assets.compile = false`, the app built its manifest at boot from the file
      # on disk. In a fresh checkout (CI) there was none, so `app.assets_manifest` and the ActionView
      # copy are empty. The rake task above writes a new manifest through its own Sprockets::Manifest
      # instance and never updates those objects, and every stylesheet_link_tag/javascript_include_tag
      # then raises AssetNotPrecompiledError (rendered as HTTP 500). Reload from the file just written.
      Rails.application.assets_manifest = Sprockets::Railtie.build_manifest(Rails.application)
      ActionView::Base.assets_manifest = Rails.application.assets_manifest
    end
  end
end
