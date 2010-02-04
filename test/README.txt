
= testing ruote-dm

where you have 

  ruote/
  ruote-dm/

in the same directory, you can go to ruote/ and do

  ruby test/unit/ut_17_storage.rb --dm

or

  ruby test/functional/test.rb --dm

to test ruote with ruote-dm as its storage.

(Make sure to "createdb ruote_test" at first).

