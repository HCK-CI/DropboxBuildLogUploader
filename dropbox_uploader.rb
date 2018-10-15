require './lib/dropbox_api'
require 'logger'
require 'octokit'
require 'json'

# Reading credentials
CONFIG_JSON = 'config.json'.freeze

config = JSON.parse(File.read(CONFIG_JSON))
GITHUB_LOGIN = config['github_credentials']['login']
GITHUB_PASSWORD = config['github_credentials']['password']
DROPBOX_TOKEN = config['dropbox_token']

# Reading CLI args
repo = ARGV[0]
commit = ARGV[1]
path = ARGV[2]

# DropboxUploader class
class DropboxUploader
  def initialize(repo, commit, path, logger = nil)
    @repo = repo
    @commit = commit
    @path = path
    @logger = logger.nil? ? Logger.new(STDOUT) : logger
  end

  def login_github(login, password)
    @logger.info('Connecting to github')
    @github = Octokit::Client.new(login: login, password: password)
  end

  def login_dropbox(token)
    @logger.info('Connecting to dropbox')
    @dropbox = DropboxAPI.new(token)
  end

  def retrieve_pr
    @logger.info('Retrieving pull request commit hash')
    @pr = @github.pulls(@repo).find { |x| x['head']['sha'] == @commit }
    return unless @pr.nil?

    @logger.fatal('Pull request commit hash not found, aborting')
    exit 1
  end
end
