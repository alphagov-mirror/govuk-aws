#!/usr/bin/env ruby

require 'net/http'
require 'net/https'
require 'json'
require 'uri'

# Fields from the command line
command, environment, stack, project, *rest= ARGV

abort("too many arguments: #{rest}") unless rest.empty?

# Valid values for each field
valid_commands = %w(plan apply plan-destroy destroy).freeze
valid_environments = %w(integration staging production test tools training).freeze
valid_stacks = %w(blue green govuk).freeze

usage = 'Usage: GITHUB_USERNAME=... GITHUB_TOKEN=... ruby deploy.rb <command> <environment> <stack> <project>'

abort("GITHUB_USERNAME environment variable must be set\n#{usage}") unless ENV.has_key?('GITHUB_USERNAME')
abort("GITHUB_TOKEN environment variable must be set\n#{usage}") unless ENV.has_key?('GITHUB_TOKEN')
abort("command must be one of #{valid_commands.join(', ')}\n#{usage}") unless valid_commands.include?(command)
abort("environment must be one of #{valid_environments.join(', ')}\n#{usage}") unless valid_environments.include?(environment)
abort("stack must be one of #{valid_stacks.join(', ')}\n#{usage}") unless valid_stacks.include?(stack)

# Make sure the user is happy to go ahead
puts "You're about to #{command} the #{stack}/#{project} project in #{environment}"
print 'Do you want to go ahead? [y/N] '
continue = STDIN.gets.chomp
abort('Build aborted') unless continue.downcase == 'y'

# Jenkins details
jenkins_url = 'https://ci-deploy.integration.publishing.service.gov.uk'.freeze
jenkins_crumb_issuer_path = '/crumbIssuer/api/json'.freeze
jenkins_job_path = '/job/Deploy_Terraform_GOVUK_AWS/buildWithParameters'.freeze
jenkins_crumb_issuer_uri = URI.parse("#{jenkins_url}#{jenkins_crumb_issuer_path}")
jenkins_job_uri = URI.parse("#{jenkins_url}#{jenkins_job_path}")

# If gds-cli has been configured, use it by default. Otherwise, use govukcli.
use_gds_cli = system("grep 'initialised: true' ~/.gds/config.yml > /dev/null 2>&1")

# Get temporary AWS credentials from either gds-cli or govukcli and set
# the corresponding environment variables to the values returned.
if use_gds_cli
  # TODO: Use local variables for the creds instead of leaking them to the
  # environment. This would be more in line with how gds-cli is intended to be
  # used. Arguably this tool shouldn't be invoking gds-cli at all and should
  # instead be invoked via `gds aws govuk-$environment -- deploy.rb ...`.
  puts 'Requesting temporary AWS credentials via "gds aws"...'
  env = `gds aws govuk-#{environment} -e`
  abort('Could not get temporary AWS credentials') unless $?.exitstatus.zero?
  env.each_line do |env_var|
    if match = env_var.match(/(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)='(.*)'/)
      key, value = match.captures
      ENV[key] = value
    end
  end
else
  puts 'Requesting temporary AWS credentials via "govukcli aws"...'
  `govukcli set-context #{environment}`
  env = `govukcli aws invoke printenv`
  abort('Could not get temporary AWS credentials') unless $?.exitstatus.zero?
  aws_credential_env_vars = %w(AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN).freeze
  env.each_line do |env_var|
    key, value = env_var.split('=')
    ENV[key] = value.chomp if aws_credential_env_vars.include?(key)
  end
end

# Get a Jenkins "crumb" to authenticate the next request
puts 'Requesting Jenkins crumb...'
jenkins_crumb_http = Net::HTTP.new(jenkins_crumb_issuer_uri.host, jenkins_crumb_issuer_uri.port)
jenkins_crumb_http.use_ssl = true
jenkins_crumb_request = Net::HTTP::Get.new(jenkins_crumb_issuer_uri.path)
jenkins_crumb_request.basic_auth(ENV['GITHUB_USERNAME'], ENV['GITHUB_TOKEN'])
jenkins_crumb_response = jenkins_crumb_http.request(jenkins_crumb_request)
abort('Could not get crumb from Jenkins') unless jenkins_crumb_response.code == '200'
jenkins_crumb = JSON.parse(jenkins_crumb_response.body)

if command == 'plan-destroy'
  # The Jenkins job uses a slightly different command
  command = 'plan (destroy)'
end

# Make a request to the Jenkins API to queue the build
puts 'Queuing Jenkins job...'
jenkins_job_http = Net::HTTP.new(jenkins_job_uri.host, jenkins_job_uri.port)
jenkins_job_http.use_ssl = true
jenkins_job_request = Net::HTTP::Post.new(jenkins_job_uri.path)
jenkins_job_request.basic_auth(ENV['GITHUB_USERNAME'], ENV['GITHUB_TOKEN'])
jenkins_job_request.set_form_data({
  'AWS_ACCESS_KEY_ID' => ENV['AWS_ACCESS_KEY_ID'],
  'AWS_SECRET_ACCESS_KEY' => ENV['AWS_SECRET_ACCESS_KEY'],
  'AWS_SESSION_TOKEN' => ENV['AWS_SESSION_TOKEN'],
  'COMMAND' => command,
  'ENVIRONMENT' => environment,
  'STACKNAME' => stack,
  'PROJECT' => project
})
jenkins_job_request[jenkins_crumb['crumbRequestField']] = jenkins_crumb['crumb']
jenkins_job_response = jenkins_job_http.request(jenkins_job_request)

abort('Could not queue Jenkins job') unless jenkins_job_response.code == '201'

puts 'Jenkins job queued'
