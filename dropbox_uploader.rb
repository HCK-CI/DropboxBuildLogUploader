require 'json'
require 'logger'

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
end
