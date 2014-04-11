storyRegex = /Sprint \d+$/
boardUrlRegex = /^https:\/\/trello.com\/\S+\/\S+\//
boardParams = 'lists=open&list_fields=name,pos&cards=open&card_fields=all'
shortUrlOf = (url) -> (boardUrlRegex.exec(url) || [''])[0]
dictOf = (collection, key, values) -> _(collection).indexBy(key).mapValues(values).value()


trellato = (angular.module 'trellato', [])

trellato.value('global', {})

trellato.factory 'getConfig', ($http, $q, global) ->
	deferred = $q.defer()
	($http.get 'trellato.config.js')
		.then((response) -> 
			global.orgId = response.data.orgId
			deferred.resolve response.data
		)
		.catch( -> window.alert "There was an error loading trellato.config.js. Copy and modify from trellato.config_example.js.")
	deferred.promise

trellato.factory 'loadTrello', (getConfig, $q) ->
	deferredTrello = $q.defer()	
	getConfig.then (config) ->
		window.require ["https://api.trello.com/1/client.js?key=#{ config.trelloApiKey }"], ->
			deferredTrello.resolve window.Trello
	deferredTrello.promise

trellato.service 'trello', ($q, loadTrello) -> 
	(apiUrl) -> 
		deferred = $q.defer()
		loadTrello.then (trello) -> trello.get apiUrl, (data) -> deferred.resolve data
		deferred.promise

	
trellato.factory('getLists', (global) -> (board) ->
	for list in _.sortBy board.lists, 'pos'
		list.cards = for card in board.cards when card.idList == list.id
			card.boardId = global.boardIds[shortUrlOf(card.desc)] if card.desc?
			card
		list
)

trellato.controller 'mainCtrl', ($scope, loadTrello, trello, global, getLists) ->
	onSuccess = -> 
		$scope.isLoggedIn = true
		(trello "organizations/#{ global.orgId }/boards").then((boards) ->
			
			# populate the sprintBoards combo
			$scope.sprintBoards = for b in boards when storyRegex.test b.name
				{id: b.id, name: b.name}
			
			_.each boards, (board) -> board.url = shortUrlOf board.url      
			global.boardIds = dictOf boards, 'url', 'id'

			# select the latest sprint board
			$scope.selectBoard $scope.selectedBoard = 
				$scope.sprintBoards[-1..][0].id
		)

	$scope.login = -> 
		loadTrello.then((Trello) -> Trello.authorize {type: 'popup', success: -> $scope.$apply onSuccess })

	$scope.selectBoard = (boardId) -> 
		Trello.get "boards/#{ boardId }?#{ boardParams }&members=all", (board) ->
			$scope.storyLists = getLists board
			global.members = _.indexBy board.members, 'id'
			$scope.$apply()

	$scope.global = global

	# try to automatically connect to trello with saved cookie
	loadTrello.then (Trello) -> 
		Trello.authorize {interactive: false, success: onSuccess}


trellato.directive('trellable', () -> {
	restrict: 'E',
	template: '''
		<div class='storylist' ng-repeat='list in storyLists'>
			<div class='listname'>{{list.name}} ({{list.cards.length}})</div>
			<div class='listcards'>
				<div ng-repeat='story in list.cards' ng-class='{storyrow: story.boardId}' story='story'></div>
			</div>
			<div style='clear: left'></div>
		</div>'''  
})

trellato.directive('story', () -> {
  scope: { story: '=' },
  template: '''
	  		<div class='story'><div card='story'></div></div>
			<div class='tasklist' ng-repeat='list in taskLists'>
				<div class='listname'>{{list.name}}</div>
				<div class='listcards'>
					<div ng-repeat='card in list.cards' card='card'></div>
				</div>
				<div style="height: 1px; width: 100%;"></div>
			</div>
			<div style='clear: left'></div>
		'''
  controller: ($scope, getLists) ->
    if $scope.story.boardId
      Trello.get "boards/#{ $scope.story.boardId }?#{ boardParams }", (storyBoard) ->
        $scope.taskLists = getLists storyBoard
        $scope.$apply()
})

trellato.directive('card', () -> {
  scope: { card: '=' }
  replace: 'element'
  template: '''
    <div class="card" ng-class="labels" ng-click="click()">
      <div><a ng-href="{{card.url}}" target="_blank">{{card.name}}</a></div>
      <div class='members'>
        <span ng-repeat='member in members' class='member' 
        title='{{member.fullName}}'
        ng-bind='member.initials'></span>
      </div>
    </div>'''
  controller: ($scope, global) ->
    $scope.labels = (l.color for l in $scope.card.labels)
    $scope.members = (global.members[id] for id in $scope.card.idMembers)
    $scope.click = -> 
      console.log $scope.card
})








angular.element(window.document).ready ->
	angular.bootstrap window.document, ['trellato']