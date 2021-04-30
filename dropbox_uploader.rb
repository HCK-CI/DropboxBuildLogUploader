# frozen_string_literal: true

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
  DROPBOX_TOKEN = config['dropbox_token']
else
  GITHUB_LOGIN = ENV['AUTOHCK_GITHUB_LOGIN']
  GITHUB_PASSWORD = ENV['AUTOHCK_GITHUB_TOKEN']
  DROPBOX_TOKEN = ENV['AUTOHCK_DROPBOX_TOKEN']
end

# Reading CLI args
repo = ARGV[0]
commit = ARGV[1]
path = ARGV[2]
commit_status_context = ARGV[3] || 'HCK-CI'

# DropboxUploader class
class DropboxUploader
  def initialize(repo, commit, commit_status_context, path, logger = nil)
    @repo = repo
    @commit = commit
    @commit_status_context = commit_status_context
    @path = path
    @logger = logger.nil? ? Logger.new($stdout) : logger
  end

  def login_github(login, password)
    @logger.info('Connecting to github')
    @github = Octokit::Client.new(login: login, password: password)
  end

  def login_dropbox(token)
    @logger.info('Connecting to dropbox')
    @dropbox = DropboxApi::Client.new(token)
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
      return
    end
    @logger.info('Creating remote dropbox folder')
    current_time = Time.now.strftime('%Y_%m_%d_%H_%M_%S')
    remote_path = "PR #{@pr['number']} - #{current_time}"
    @dropbox.create_folder(remote_path)
    @target_url = @dropbox.url
  end

  def retrieve_last_status
    @logger.info('Retrieving current status info')
    statuses_list = @github.combined_status(@repo, @commit).statuses
    @last_status  = statuses_list.find { |status| status.context == @commit_status_context }
  end

  def update_status
    if @last_status.nil?
      @logger.error('Last status not available')
      return
    end
    options = { 'context' => @last_status.context,
                'description' => @last_status.description,
                'target_url' => @target_url }
    @logger.info('Updating current status with remote url')
    @github.create_status(@repo, @commit, @last_status.state, options)
  end

  def upload_files
    @logger.info('Uploading files')
    Dir.new(@path).each do |file|
      fullpath = "#{@path}/#{file}"
      next unless File.file?(fullpath)

      @dropbox.upload_file(fullpath)
    end
  end
end

dropbox_uploader = DropboxUploader.new(repo, commit, commit_status_context, path)
dropbox_uploader.login_github(GITHUB_LOGIN, GITHUB_PASSWORD)
dropbox_uploader.login_dropbox(DROPBOX_TOKEN)
dropbox_uploader.retrieve_pr
dropbox_uploader.create_remote_folder
dropbox_uploader.retrieve_last_status
dropbox_uploader.update_status
dropbox_uploader.upload_files
