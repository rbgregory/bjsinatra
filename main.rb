require 'rubygems'
require 'sinatra'
#require 'pry'

ACE= "A"
ACE_VALUE = 11
ACE_VALUE_ALT = 1
FACE_CARD_VALUE = 10
DEALER_LIMIT = 17
BLACKJACK = 21

CARD_SUIT = 0
CARD_VALUE = 1

PLAYER_CASH = 500

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
    #card_values.select{|value| value == ACE}.count.times do
    card_values.count(ACE).times do
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
  
  def winner!(msg)
    @game_over = true
    @show_hit_or_stay_buttons = false
    session[:player_cash] = session[:player_cash] + session[:player_bet]
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
  end

  def loser!(msg)
    @game_over = true
    @show_hit_or_stay_buttons = false
    session[:player_cash] = session[:player_cash] - session[:player_bet]
    @loser = "<strong>#{session[:player_name]} loses.</strong> #{msg}"
  end

  def tie!(msg)
    @game_over = true
    @show_hit_or_stay_buttons = false
    @winner = "<strong>It's a tie!</strong> #{msg}"
  end

end

def change_player_cash cash
  session[:player_cash] += cash
end

def check_game_over?
  @show_hit_or_stay_buttons = false
  @show_dealer_cards = true
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK
    loser!("Dealer hit blackjack!")
    true
  elsif dealer_total > BLACKJACK
    winner!("Dealer busted at #{dealer_total}!")
    @show_dealer_turn_button = false
    true
  else
    if dealer_total >= DEALER_LIMIT
      player_total = calculate_total(session[:player_cards])
      if dealer_total > player_total
        loser!("Dealer stayed at #{dealer_total} and #{session[:player_name]} stayed at #{player_total}.")
      elsif dealer_total < player_total
        winner!("Dealer stayed at #{dealer_total} and #{session[:player_name]} stayed at #{player_total}.")
      else
        tie!("Both Dealer and #{session[:player_name]} stayed at #{player_total}.")
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
    redirect '/bet'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_cash] = PLAYER_CASH
  session[:player_bet] = nil
  erb :set_name
end

post '/set_name' do
  if params['username'].empty?
    @error = "Name is required"
    halt erb :set_name
  end
  session[:player_name] = params['username']
  redirect '/bet'
end

get '/bet' do
  if session[:player_cash] > 0
    erb :bet
  else
    redirect '/game_over'
  end
end

post '/player_bet' do
  if params[:bet_amount].empty? || params[:bet_amount].to_i == 0
    @error = "Must make a bet"
    halt erb :bet
  elsif params[:bet_amount].to_i < 0
    @error = "Not a valid bet."
    halt erb :bet
  elsif params[:bet_amount].to_i > session[:player_cash]
    @error = "You cannot bet more than you have, which is #{session[:player_cash]}."
    halt erb :bet
  else
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
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
    winner!("#{session[:player_name]} hit blackjack.")
  end
  erb :game
end

post '/game/player/hit' do
  # if the player requests a hit, deal a card and check if player has hit
  # blackjack or busted.
  session[:player_cards] << session[:deck].pop
  redirect '/game/player'
end

get '/game/player' do
  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK
    winner!("#{session[:player_name]} hit blackjack.")
  elsif player_total > BLACKJACK
    loser!("It looks like #{session[:player_name]} busted at #{player_total}.")
  end
  erb :game, layout: false
end

post '/game/player/stay' do
  redirect '/game/dealer'
end

post '/game/dealer/turn' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/dealer' do
  @game_over = check_game_over?
  @show_dealer_turn_button = true if !@game_over
  erb :game, layout: false
end

get '/game/goodbye' do
  erb :goodbye
end

get '/game_over' do
  erb :game_over
end