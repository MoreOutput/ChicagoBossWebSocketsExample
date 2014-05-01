-module(app_feed_websocket, [Req, SessionId]).
-behaviour(boss_service_handler).
-record(state, {users}).
-export([init/0, 
    handle_incoming/4, 
    handle_join/3,
    handle_broadcast/2,
    handle_close/4, 
    handle_info/2,
    terminate/2]).

init() -> {ok, #state{users=dict:new()}}.

handle_join(ServiceName, WebSocketId, State) ->
  #state{users=Users} = State,
  User = dict:store(WebSocketId, [{session, SessionId}], Users),
  {noreply, #state{users=User}}.

handle_close(Reason, ServiceName, WebSocketId, State) ->
  #state{users=Users} = State,
  {noreply, #state{users=dict:erase(WebSocketId, Users)}}.

handle_broadcast(Message, State) ->
  {noreply, State}.

handle_incoming(ServiceName, WebSocketId, Message, State) ->
  {struct, IncomingMessage} = mochijson2:decode(Message),
  Type = proplists:get_value(<<"type">>, IncomingMessage, 0),
  if Type == <<"edit">> -> process_post(ServiceName, WebSocketId, IncomingMessage, State);
    true -> ok.
  end.

% Saving something and updating the other users
process_post(ServiceName, WebSocketId, IncomingMessage, State) ->
  ID = binary_to_list(proplists:get_value(<<"id">>, IncomingMessage, "None")),
  Post = boss_db:find(ID),
  {_, _, _, _, Likes, _, _, {_,_,_,_}} = Pic,
  UpdatedPost = Post:set( [{title, "Hello World"}] ),
  case UpdatedPost:save() of
    {ok, Saved} -> 
      broadcast({[{type, edit}, {id, list_to_binary(ID)}]}, WebSocketId, State),
      {noreply, State}
  end.

handle_info(state, State) ->
  #state{users=Users} = State,
  error_logger:info_msg("state:~p~n", [Users]),
  {noreply, State};

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

%% Specific to sending JSON data to the correct users

% to users who are not the user
broadcast(Message, WebSocketId, State) ->
  #state{users=Users} = State,
  AllUsers = dict:fetch_keys(Users),
  send_to(Message, WebSocketId, AllUsers, State).

% send to specific websocket
send(Message, WebSocketId) ->
  WebSocketId ! {text,  mochijson2:encode(Message)}.

% Filter for send and broadcast
send_to(Message, WebSocketId, [], State) -> ok;

send_to(Message, WebSocketId, [H|T], State) ->
  {_,User} = dict:find(H, State#state.users),
  send(Message, H),
  send_to(Message, WebSocketId, T, State).