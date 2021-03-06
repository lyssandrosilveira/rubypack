require_relative '../spec_helper'

describe "Rails 6" do
  it "should detect successfully" do
    Hatchet::App.new('rails6-basic').in_directory_fork do
      expect(LanguagePack::Rails5.use?).to eq(false)
      expect(LanguagePack::Rails6.use?).to eq(true)
    end
  end

  it "calls bin/yarn no matter what is on the path" do
    Hatchet::Runner.new("rails6-basic").tap do |app|
      # We put our version of yarn first on the path ahead of bin/yarn
      # however webpacker explicitly calls bin/yarn instead of calling
      # `yarn install`
      app.before_deploy do
        File.open("bin/yarn", "w") do |f|
          f.write <<~EOM
          #! /usr/bin/env bash

          echo "Called bin/yarn binstub"
          `yarn install`
          EOM
        end
        run("chmod +x bin/yarn")
      end

      app.deploy do
        expect(app.output).to include("Called bin/yarn binstub")

        expect(app.output).to match("rake assets:precompile")
        expect(app.output).to match("rake assets:clean")
      end
    end
  end

  it "deploys and serves web requests via puma" do
    before_deploy = Proc.new do
      run! "echo 'web: bundle exec puma -t 5:5 -p ${PORT:-3000} -e ${RACK_ENV:-development}' > Procfile"

      # Test Clean task does not get called if it does not exist
      # This file will only have the `assets:precompile` task in it, but not `assets:clean`
      run! %Q{echo 'task "assets:precompile" do ; end' > Rakefile}
    end

    Hatchet::Runner.new('rails6-basic', before_deploy: before_deploy).deploy do |app|
      expect(app.output).to match("Fetching railties 6")

      expect(app.output).to match("rake assets:precompile")
      expect(app.output).to_not match("rake assets:clean")

      expect(web_boot_status(app)).to_not eq("crashed")
    end
  end
end
