describe 'stuff', ->

	beforeEach ->
		angular.mock.module 'trellato.trello'

	it 'is a test', inject((foo) ->
		console.log 'foo', foo
	)