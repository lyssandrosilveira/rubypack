require_relative '../spec_helper'

describe "Rails 5" do
  it "behaves correctly, not related to Rails 5 at all" do
    Hatchet::Runner.new("ruby-getting-started", stack: "heroku-18").deploy do |app, heroku|
      # Test BUNDLE_DISABLE_VERSION_CHECK works
      expect(app.output).not_to include("The latest bundler is")

      # Test worker task only appears if the app has that rake task
      worker_task = worker_task_for_app(app)
      expect(worker_task).to be_nil

      run!(%Q{echo "task 'jobs:work' do ; end" >> Rakefile})
      app.commit!

      app.deploy do
        worker_task = worker_task_for_app(app)
        expect(worker_task["command"]).to eq("bundle exec rake jobs:work")
      end
    end
  end

  def worker_task_for_app(app)
    app
     .api_rate_limit.call
     .formation
     .list(app.name)
     .detect { |h| h["type"] == "worker" }
  end

  it "blocks bads sprockets config with bad version" do
    Hatchet::Runner.new(
      "sprockets_asset_compile_true",
      stack: "heroku-18",
      allow_failure: true,
      config: {'HEROKU_DEBUG_RAILS_RUNNER' => 'true'}
    ).deploy do |app, heroku|
      expect(app.output).to match("heroku.detecting.config.for.assets.compile=true")
      expect(app.output).to match('A security vulnerability has been detected')
      expect(app.output).to match('version "3.7.2"')
    end
  end
end

