-module(aec_mining_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

-include("common.hrl").
-include("blocks.hrl").

-define(TEST_MODULE, aec_mining).

mine_block_test_() ->
    {foreach,
     fun() ->
             meck:new(aec_pow_sha256),
             meck:new(aec_tx, [passthrough])
     end,
     fun(_) ->
             meck:unload(aec_pow_sha256),
             meck:unload(aec_tx)
     end,
     [
      {"Find a new block",
       fun() ->
               Trees = #trees{accounts = [#account{pubkey = <<"pubkey">>}]},
               meck:expect(aec_pow_sha256, recalculate_difficulty, 3, 856),
               meck:expect(aec_pow_sha256, generate, 3, {ok, 721}),
               meck:expect(aec_tx, apply_signed, 3, {ok, Trees}),

               {ok, Block} = ?TEST_MODULE:mine(),
               ?assertEqual(1, Block#block.height),
               ?assertEqual(721, Block#block.nonce),
               ?assertEqual(1, length(Block#block.txs))
       end},
      {"Proof of work fails with generation_count_exhausted",
       fun() ->
               Trees = #trees{accounts = [#account{pubkey = <<"pubkey">>}]},
               meck:expect(aec_pow_sha256, recalculate_difficulty, 3, 856),
               meck:expect(aec_pow_sha256, generate, 3, {error, generation_count_exhausted}),
               meck:expect(aec_tx, apply_signed, 3, {ok, Trees}),

               ?assertEqual({error, generation_count_exhausted}, ?TEST_MODULE:mine())
       end},
      {"Cannot apply signed tx",
       fun() ->
               meck:expect(aec_pow_sha256, recalculate_difficulty, 3, 856),
               meck:expect(aec_pow_sha256, generate, 3, {ok, 721}),
               meck:expect(aec_tx, apply_signed, 3, {error, tx_failed}),

               ?assertEqual({error, tx_failed}, ?TEST_MODULE:mine())
       end}
     ]
    }.

-endif.