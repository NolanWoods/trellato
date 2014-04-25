storyRegex = /Sprint \d+$/
boardUrlRegex = /^https:\/\/trello.com\/\S+\/\S+\//
boardParams = 'lists=open&list_fields=name,pos&cards=open&card_fields=all'
shortUrlOf = (url) -> (boardUrlRegex.exec(url) || [''])[0]
dictOf = (collection, key, values) -> _(collection).indexBy(key).mapValues(values).value()


trellato = angular.module 'trellato', ['angularLocalStorage']

trellato.value 'global', {}


trellato.service 'trello', ($q) -> (apiUrl) -> 
	deferred = $q.defer()
	Trello.get apiUrl, (data) -> deferred.resolve data
	deferred.promise

	
trellato.factory 'getLists', (global) -> (board) ->
	for list in _.sortBy board.lists, 'pos'
		list.cards = for card in board.cards when card.idList == list.id
			card.boardId = global.boardIds[shortUrlOf(card.desc)] if card.desc?
			card
		list

trellato.controller 'mainCtrl', ($scope, trello, global, getLists, storage) ->
	onSuccess = -> 
		$scope.isLoggedIn = true
		trello "organizations/#{ window.orgId }/boards"
			.then((boards) ->
				
				# populate the sprintBoards combo
				$scope.sprintBoards = for b in boards when storyRegex.test b.name
					{id: b.id, name: b.name}
				
				_.each boards, (board) -> board.url = shortUrlOf board.url      
				global.boardIds = dictOf boards, 'url', 'id'

				# select the latest sprint board
				$scope.selectBoard $scope.selectedBoard = $scope.sprintBoards[-1..][0].id
			)

	$scope.login = -> 
		Trello.authorize {type: 'popup', success: -> $scope.$apply onSuccess }

	$scope.selectBoard = (boardId) -> 
		Trello.get "boards/#{ boardId }?#{ boardParams }&members=all", (board) ->
			$scope.storyLists = getLists board
			global.members = _.indexBy board.members, 'id'
			$scope.$apply()

	storage.bind $scope, 'options', { defaultValue: {enableStacking: true} }
	$scope.global = global

	# try to automatically connect to trello with saved cookie
	Trello.authorize {interactive: false, success: onSuccess}


trellato.directive 'trellable', () -> 
	restrict: 'E',
	template: '''
		<div class='trellable' ng-repeat='list in storyLists'>
			<listname></listname>
			<div class='listcards'>
				<div ng-repeat='story in list.cards' ng-class='{storyrow: story.boardId}' story></div>
			</div>
			<div style='clear: left'></div>
		</div>''' 


trellato.directive 'listname', () -> 
	restrict: 'E'
	replace: 'element'
	template: '''
			<div class='listname'>{{list.name}} <span ng-show='list.cards.length > 0'>({{list.cards.length}})</span></div>
		'''  


trellato.directive 'story', () -> 
	template: '''
		<table>
			<colgroup>
				<col style='width: {{colwidth}}'>
				<col ng-repeat='l in taskLists' style='width: {{colwidth}}'>
			</colgroup>
			<tr>
				<td ng-class='{story: taskLists}'>
					<div card='story'></div>
				</td>
				<td ng-repeat='list in taskLists'>
					<div tasklist></div>
				</td>
			</tr>
		</table>'''
	controller: ($scope, getLists) ->
		$scope.colwidth = '500px'
		if $scope.story.boardId
			Trello.get "boards/#{ $scope.story.boardId }?#{ boardParams }", (storyBoard) ->
				$scope.taskLists = getLists storyBoard
				$scope.colwidth = (100 / ($scope.taskLists.length + 1)) + '%' if $scope.taskLists.length > 0
				$scope.$apply()


trellato.directive 'tasklist', () -> 
	scope: true,
	controller: ($scope, $timeout) ->
		collapsing = false
		$scope.expand = ->
			if collapsing then $timeout.cancel collapsing
			$scope.expanded = true;
		$scope.collapse = ->
			collapsing = $timeout((-> $scope.expanded = false), 500)
	template: '''
		<div class='tasklist' ng-mouseenter='expand()' ng-mouseleave='collapse()' 
				ng-class='{stackable: options.enableStacking}'>
			<listname></listname>
			<div class='listcards' ng-class='{stacked: !expanded && options.enableStacking}'>
				<div ng-repeat='card in list.cards' card='card'></div>
			</div>
			<div style="height: 1px; width: 100%;"></div>
		</div>
		'''


trellato.directive 'card', () -> 
  scope: { card: '=' }
  replace: 'element'
  template: '''
    <div class="card" ng-class="labels" ng-click="click()">
		<span class='members'>
			<span ng-repeat='member in members' class='member' title='{{member.fullName}}'>{{member.initials}}</span>
		</span>
		<div title='{{card.name}}'>
			<a href='{{url}}' target='_blank'>{{card.name}}</a>
		</div>
    </div>'''
  controller: ($scope, global) ->
    $scope.labels = (l.color for l in $scope.card.labels)
    $scope.members = (global.members[id] for id in $scope.card.idMembers)
    $scope.url = if $scope.card.boardId then $scope.card.desc else $scope.card.url
    $scope.click = -> console.log $scope.card
