-module(acceptable).

-export([choose/2]).

-type accept() :: {mediatype(), quality(), [param()]}.
-type mediatype() :: {maintype(), subtype(), [param()]}.
-type maintype() :: binary().
-type subtype() :: binary().
-type param() :: binary().
-type quality() :: float().

-spec choose([accept()], [mediatype()])
  -> {ok, mediatype()}
  | {error, unacceptable}.
choose(undefined, []) ->
  {error, unacceptable};
choose(undefined, [Type|_]) ->
  {ok, Type};
choose([], [Type|_]) ->
  {ok, Type};
choose(Accept, Provided) ->
  Accept2 = prioritize_accept(Accept),
  choose_mediatype({Accept2, Provided}).

prioritize_accept(Accept) ->
  lists:sort(fun
    ({TypeA, Q, _}, {TypeB, Q, _}) ->
      prioritize_mediatype(TypeA, TypeB);
    ({_, QA, _}, {_, QB, _}) ->
      QA > QB
  end, Accept).

%% more specific types win. choose B if inconclusive.
prioritize_mediatype({TypeA, SubTypeA, ParamsA}, {TypeB, SubTypeB, ParamsB}) ->
  case TypeB of
    TypeA ->
      case SubTypeB of
        SubTypeA -> length(ParamsA) > length(ParamsB);
        <<"*">> -> true;
        _ -> false
      end;
    <<"*">> -> true;
    _ -> false
  end.

choose_mediatype({[], _}) ->
  {error, unacceptable};
choose_mediatype({[Type|Accept], Provided}) ->
  match_mediatype({Provided, Accept}, Provided, Type).

match_mediatype(S, [], _Type) ->
  choose_mediatype(S);
match_mediatype(S, Provided, Type = {{<<"*">>, <<"*">>, _}, _, _}) ->
  match_params(S, Provided, Type);
match_mediatype(S, Provided = [{Type, SubTypeA, _}|_], MType = {{Type, SubTypeB, _}, _, _})
    when SubTypeA =:= SubTypeB; SubTypeB =:= <<"*">> ->
  match_params(S, Provided, MType);
match_mediatype(S, [_|Provided], Type) ->
  match_mediatype(S, Provided, Type).

match_params(_S, [{Type, SubType, '*'}|_], {{Type, SubType, Params}, _, _}) ->
  {ok, {Type, SubType, Params}};
match_params(S, [Selected = {_, _, A}|Provided], Type = {{_, _, B}, _, _}) ->
  case lists:sort(A) =:= lists:sort(B) of
    true ->
      {ok, Selected};
    false ->
      match_mediatype(S, Provided, Type)
  end.

-ifdef(TEST).

-define(JSON, ?JSON('*')).
-define(JSON(P), {<<"application">>, <<"json">>, P}).
-define(JSON(P, Q), {?JSON(P), Q, P}).

-define(HTML, ?HTML('*')).
-define(HTML(P), {<<"text">>, <<"html">>, P}).
-define(HTML(P, Q), {?HTML(P), Q, P}).

choose_test() ->
  {error, unacceptable} = choose(undefined, []),
  {ok, ?JSON} = choose(undefined, [?JSON, ?HTML]),
  {ok, ?JSON} = choose([], [?JSON, ?HTML]),
  {ok, ?HTML([])} = choose([?HTML([], 1.0)], [?JSON, ?HTML]),
  {ok, ?JSON([])} = choose([?JSON([], 1.0)], [?JSON, ?HTML]),
  {ok, ?JSON([])} = choose([?JSON([], 1.0), ?HTML([], 0.9)], [?JSON, ?HTML]),
  {ok, ?JSON([])} = choose([?HTML([], 0.9), ?JSON([], 1.0)], [?JSON, ?HTML]),
  {ok, ?HTML([])} = choose([?JSON([], 0.9), ?HTML([], 1.0)], [?JSON, ?HTML]),
  {ok, ?HTML([1, 2, 3])} = choose([?JSON([1, 2], 1.0), ?HTML([1, 2, 3], 1.0)], [?JSON, ?HTML]),
  {ok, ?JSON([1, 2])} = choose([?HTML([1, 2, 3], 1.0), ?JSON([1, 2], 1.0)], [?JSON, ?HTML]),
  {error, unacceptable} = choose([?JSON([2], 1.0), ?HTML([5], 1.0)], [?JSON([1])]),
  {ok, ?JSON([2])} = choose([?HTML([5], 1.0), ?JSON([2], 1.0)], [?JSON([2])]),
  {ok, ?HTML([5])} = choose([?JSON([2], 1.0), ?HTML([5], 1.0)], [?JSON([2]), ?HTML([5])]),
  ok.

-endif.
