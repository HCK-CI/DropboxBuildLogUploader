require './lib/dropbox_api'

# Reading credentials
CONFIG_JSON = 'config.json'.freeze

config = JSON.parse(File.read(CONFIG_JSON))
GITHUB_LOGIN = config['github_credentials']['login']
GITHUB_PASSWORD = config['github_credentials']['password']
DROPBOX_TOKEN = config['dropbox_token']
