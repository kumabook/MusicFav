require 'json'

config = ""
open("MusicFav/fabric.json") do |io|
  config = JSON.load(io)
end

if config["api_key"] == "api_key" || config["build_secret"] == "build_secret"
  puts "Skip fabric script because the fabric.json is not set correctly."
  exit
end
run_command = "./Pods/CrashlyticsFramework/Crashlytics.framework/run"
success = system("#{run_command} #{config["api_key"]} #{config["build_secret"]}")
if success
  puts "Succeeded in running fabric script"
else
  puts "Failed to run fabric script"
end
