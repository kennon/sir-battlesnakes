require 'rack'
require 'rack/contrib'
require 'sinatra'
require './util'

Dir[File.join(__dir__, 'snakes', '*.rb')].each { |file| require file }

SNAKE=ENV['SNAKE'].constantize.new

use Rack::PostBodyContentTypeParser
# This function is called when you register your Battlesnake on play.battlesnake.com
# It controls your Battlesnake appearance and author permissions.
# TIP: If you open your Battlesnake URL in browser you should see this data
get '/' do
  camelcase(SNAKE.appearance).to_json
end

# This function is called everytime your snake is entered into a game.
# rack.request.form_hash contains information about the game that's about to be played.
# TODO: Use this function to decide how your snake is going to look on the board.
post '/start' do
  data = underscore(env['rack.request.form_hash'])
  SNAKE.start(data)
  puts "START"
  "OK\n"
end

# This function is called on every turn of a game. It's how your snake decides where to move.
# Valid moves are "up", "down", "left", or "right".
# TODO: Use the information in rack.request.form_hash to decide your next move.
post '/move' do
  content_type :json

  gamestate = underscore(env['rack.request.form_hash'])
  move = SNAKE.move(gamestate)

  response = camelcase({ "move": move }).to_json
  puts ">> #{response}"
  response
end

# This function is called when a game your Battlesnake was in ends.
# It's purely for informational purposes, you don't have to make any decisions here.
post '/end' do
  data = underscore(env['rack.request.form_hash'])
  SNAKE.end(data)
  puts "END"
  "OK\n"
end
