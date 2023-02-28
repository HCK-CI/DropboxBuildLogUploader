# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'dropbox_api'
require 'logger'
require 'octokit'
require 'json'

# Reading credentials
CONFIG_JSON = 'config.json'

if File.exist?(CONFIG_JSON)
  config = JSON.parse(File.read(CONFIG_JSON))
  GITHUB_LOGIN = config['github_credentials']['login']
  GITHUB_PASSWORD = config['github_credentials']['password']
  DROPBOX_TOKEN_JSON = config['dropbox_token_json']
  DROPBOX_CLIENT_ID = config['dropbox_client_id']
  DROPBOX_CLIENT_SECRET = config['dropbox_client_secret']
else
  GITHUB_LOGIN = ENV.fetch('AUTOHCK_GITHUB_LOGIN', nil)
  GITHUB_PASSWORD = ENV.fetch('AUTOHCK_GITHUB_TOKEN', nil)
  DROPBOX_TOKEN_JSON = ENV.fetch('AUTOHCK_DROPBOX_TOKEN_JSON', nil)
  DROPBOX_CLIENT_ID = ENV.fetch('AUTOHCK_DROPBOX_CLIENT_ID', nil)
  DROPBOX_CLIENT_SECRET = ENV.fetch('AUTOHCK_DROPBOX_CLIENT_SECRET', nil)
end

# Reading CLI args
options = {
  repo: ARGV[0],
  commit: ARGV[1],
  path: ARGV[2],
  commit_status_context: ARGV[3] || 'HCK-CI',
  commit_status_description: ARGV[4],
  commit_status_state: ARGV[5],
  commit_status_create: ARGV[6]
}

# DropboxUploader class
class DropboxUploader
  def initialize(options, logger = nil)
    @repo = options[:repo]
    @commit = options[:commit]
    @commit_status_context = options[:commit_status_context]
    @commit_status_description = options[:commit_status_description]
    @commit_status_create = options[:commit_status_create]
    @commit_status_state = options[:commit_status_state]
    @path = options[:path]
    @logger = logger.nil? ? Logger.new($stdout) : logger
  end

  def login_github(login, password)
    @logger.info('Connecting to github')
    @github = Octokit::Client.new(login: login, password: password)
  end

  def init_dropbox(client_id, client_secret, token_file)
    @logger.info('Initializing dropbox')
    @token_file = token_file

    @authenticator = DropboxApi::Authenticator.new(client_id, client_secret)
  end

  def ask_token
    url = @authenticator.auth_code.authorize_url(token_access_type: 'offline')
    @logger.info("Navigate to #{url}")
    @logger.info('Please enter authorization code')

    code = $stdin.gets.chomp
    @token = @authenticator.auth_code.get_token(code)

    save_token(@token)
  end

  def save_token(token)
    @logger.info('Dropbox token to be saved in the local file')

    File.write(@token_file, token.to_hash.to_json)
  end

  def load_token
    @logger.info('Loading Dropbox token from the local file')

    return nil unless File.exist?(@token_file)

    begin
      hash = JSON.parse(File.read(@token_file))
    rescue StandardError => e
      @logger.warn("Loading Dropbox token error: (#{e.class}) #{e.message}")

      return nil
    end

    @token = OAuth2::AccessToken.from_hash(@authenticator, hash)
  end

  def login_dropbox
    @dropbox = DropboxApi::Client.new(
      access_token: @token,
      on_token_refreshed: lambda { |new_token|
        save_token(new_token)
      }
    )
  end

  def connect_dropbox
    load_token if @token.nil?

    if @token
      login_dropbox
    else
      @logger.info('Dropbox token missing')
    end

    if @dropbox.nil?
      @logger.warn('Dropbox authentication failure, aborting')
      exit 1
    end
  rescue DropboxApi::Errors::HttpError
    @logger.fatal('Dropbox connection error, aborting')
    exit 1
  end

  def retrieve_pr
    @logger.info('Retrieving pull request commit hash')
    @pr = @github.pulls(@repo).find { |x| x['head']['sha'] == @commit }
    return unless @pr.nil?

    @logger.fatal('Pull request commit hash not found, aborting')
    exit 1
  end

  def create_remote_folder
    if @pr.nil?
      @logger.error('No pull request commit hash')
      exit 1
    end
    @logger.info('Creating remote dropbox folder')
    current_time = Time.now.strftime('%Y_%m_%d_%H_%M_%S')
    @remote_path = "/#{@repo}/Build/PR #{@pr['number']} - #{current_time}"
    @dropbox.create_folder(@remote_path)
    @url = "#{@dropbox.create_shared_link_with_settings(@remote_path).url}&lst="
    @target_url = @url
  end

  def retrieve_last_status
    @logger.info('Retrieving current status info')
    statuses_list = @github.combined_status(@repo, @commit).statuses
    @last_status  = statuses_list.find { |status| status.context == @commit_status_context }
  end

  def update_status
    if @commit_status_create == '--create'
      context = @commit_status_context
      description = @commit_status_description
      state = @commit_status_state
    elsif @last_status.nil?
      @logger.error('Last status not available')
      exit 1
    else
      context = @last_status.context
      description = @last_status.description
      state = @last_status.state
    end

    options = { 'context' => context,
                'description' => description,
                'target_url' => @target_url }
    @logger.info('Updating current status with remote url')
    @github.create_status(@repo, @commit, state, options)
  end

  def upload_files
    @logger.info('Uploading files')
    Dir.new(@path).each do |file|
      full_path = "#{@path}/#{file}"
      next unless File.file?(full_path)

      content = File.read(full_path)
      r_path = "#{@remote_path}/#{file}"
      @dropbox.upload(r_path, content)
    end
  end
end

dropbox_uploader = DropboxUploader.new(options)
dropbox_uploader.init_dropbox(DROPBOX_CLIENT_ID, DROPBOX_CLIENT_SECRET, DROPBOX_TOKEN_JSON)
if options[:repo] == '--ask'
  dropbox_uploader.ask_token
  exit 0
end

dropbox_uploader.connect_dropbox
dropbox_uploader.login_github(GITHUB_LOGIN, GITHUB_PASSWORD)
dropbox_uploader.retrieve_pr
dropbox_uploader.create_remote_folder
dropbox_uploader.retrieve_last_status
dropbox_uploader.update_status
dropbox_uploader.upload_files
