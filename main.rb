require 'rubygems'
require 'sinatra'
require 'pry'

ACE= "A"
ACE_VALUE = 11
ACE_VALUE_ALT = 1
FACE_CARD_VALUE = 10
DEALER_LIMIT = 17
BLACKJACK = 21

CARD_SUIT = 0
CARD_VALUE = 1

#set :sessions, true
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'jellybeans' 
                           
helpers do
  # Calculate the total of the dealt cards
  def calculate_total(cards) 
    # [['H', '3'], ['S', 'Q'], ... ]
    # first create an array of just the values, not the suits
  
    #the map method creates a new array based on the block
    card_values = cards.map{|a_card| a_card[CARD_VALUE] }
  
    total = 0
    card_values.each do |value|
      if value == ACE
        total += ACE_VALUE    # an ace can be valued at 1 or 11, use 11 first
      elsif value.to_i == 0   # J, Q, K - to_{} will return 0 if non-numeric input
        total += FACE_CARD_VALUE  # for those cases the card value is 10
      else
        total += value.to_i   
      end
    end
  
    #correct for Aces, if we have blown over 21
    card_values.select{|value| value == ACE}.count.times do
      total -= (ACE_VALUE - ACE_VALUE_ALT) if total > BLACKJACK
    end
  
    total
  
  end
  
  def cover_card
    "<img src='images/cards/cover.jpg"
  end
  
  def card_image(card)
    suit = 
      case card[CARD_SUIT]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
      end
    
    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = 
        case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
        end
    end
    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end
end

def check_game_over?
  @show_hit_or_stay_buttons = false
  @show_dealer_cards = true
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK
    @error = "Dealer hit blackjack!"
    true
  elsif dealer_total > BLACKJACK
    @success = "#{session[:player_name]} wins, dealer busted at #{dealer_total}!"
    @show_dealer_turn_button = false
    true
  else
    if dealer_total >= DEALER_LIMIT
      player_total = calculate_total(session[:player_cards])
      if dealer_total > player_total
        @error = "Dealer stayed at #{dealer_total} and #{session[:player_name]} stayed at #{player_total}- dealer wins!"
      elsif dealer_total < player_total
        @success = "Dealer stayed at #{dealer_total} and #{session[:player_name]} stayed at #{player_total}-  #{session[:player_name]} wins!"
      else
        @success = "Both Dealer and #{session[:player_name]} stayed at #{player_total}- It's a tie!"
      end
    else
      false
    end
  end
end

before do
  @show_hit_or_stay_buttons = true
  @show_dealer_turn_button = false
  @show_dealer_cards = false
  @game_over = false
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  erb :set_name
end

post '/set_name' do
  if params['username'].empty?
    @error = "Name is required"
    halt erb :set_name
  end
  session[:player_name] = params['username']
  redirect '/game'
end

get '/game' do
  #Create card deck and put it in session
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!
  
  #deal cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  2.times do
    session[:dealer_cards] << session[:deck].pop
    session[:player_cards] << session[:deck].pop
  end
  
  #calculate initial player total and check if player has already hit blackjack
  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK
      @success = "Congratulations! #{session[:player_name]} hit blackjack!"
      @game_over = true
      @show_hit_or_stay_buttons = false
  end
  erb :game
end

post '/game/player/hit' do
  # if the player requests a hit, deal a card and check if player has hit
  # blackjack or busted.
  session[:player_cards] << session[:deck].pop
  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK
    @success = "Congratulations! #{session[:player_name]} hit blackjack!"
    @show_hit_or_stay_buttons = false
    @game_over = true
  elsif player_total > BLACKJACK
    @error = "Sorry, it looks like #{session[:player_name]} busted at #{player_total}."
    @show_hit_or_stay_buttons = false
    @game_over = true
  end
  erb :game
end

post '/game/player/stay' do
  @game_over = check_game_over?
  @show_dealer_turn_button = true if !@game_over
  erb :game
end

get '/busted' do
  erb :busted
end

post '/game/dealer/turn' do
  session[:dealer_cards] << session[:deck].pop
  @game_over = check_game_over?
  @show_dealer_turn_button = true if !@game_over
  erb :game
end

get '/game/goodbye' do
  erb :goodbye
end