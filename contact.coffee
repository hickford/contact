zappa = require('zappa')
port = process.env.PORT || 5000	# 5000 for consistency with foreman's default

contact = zappa.run port, ->
    enable 'default layout'     # html, head, body, etc
    enable 'serve jquery'
    use 'cookieParser', session: {secret: (require 'rbytes').randomBytes(16).toHex()}

    mongoose = require 'mongoose'
    mongoose.connect(process.env.MONGOLAB_URI || 'mongodb://localhost/contact')
    def ObjectId: mongoose.Types.ObjectId
    game_schema = new mongoose.Schema({
            secret : String,
            state : String,
            owner: String,
            date : Date,
            finished: Boolean
    })
    game_schema.virtual('remaining').get( ->
        this.secret[this.state.length..]
    )
    
    def Game: mongoose.model('Game',game_schema)

    def querystring: require 'querystring'
    
    get '/': -> 
        #@scripts = ['/zappa/zappa', '/socket.io/socket.io', '/zappa/jquery', '/contact']
        @user = session.user
        render 'index'

    get '/login': ->
        if @user
            session.user = @user
            redirect @destination or '/'
        else
            render 'login'

    get '/logout': ->
        session.user = null
        redirect '/'

    stylus '/game.css': '''
        .remaining
            color gray
    '''

    get '/new': ->
        unless session.user and @word
            return redirect '/'
        game = new Game({secret: @word, state : @word[0], owner: session.user } )
        game.save()
        console.log(game)
        redirect "/game/#{game._id}"

    get '/game/:id': ->
        @stylesheets = ['/game'] 
        try
            id = ObjectId(@id)
        catch error
            return redirect '/'
        unless session.user
            #console.log(request)
            return redirect '/login' + '?' + querystring.stringify( {destination: request.url})
        @user = session.user
        Game.findById(id, (err, game) =>             # need a timeout
            if err
                return redirect '/'
            @game = game
            @owned = (@game.owner == @user)
            #@remaining = @game.secret[@game.state.length..]
            render 'game'
        )


    view 'game': ->
        @title = 'Contact'
        h1 'A game of Contact'
        if @owned
            p "This is your game, #{@user}"
        else
            p "This is #{@user}'s game"
        if @owned
            h2 ->
                text @game.state
                span '.remaining', @game.remaining

        else
            h2 @game.state + "…"

        partial 'logout'

    view 'login': ->
        form action:'/login', method:'get', ->
            p ->
                text 'Login: '
                input type:'text', name:'user', placeholder:'user', autofocus:true, required:true
                input type:'hidden', name:'destination', value: @destination

    view 'logout': ->
        p ->
            text "You are #{@user}: "
            a href:'/logout', 'logout'

    view 'new' : ->
        h2 'New game'
        form action:'/new', method:'get', ->
            p ->
                text 'Your word: '
                input type:'text', name:'word', placeholder:'your word', autofocus:true, required:true

    view 'index' : ->
        @title = 'Contact'
        h1 @title
        p 'Contact is a word game'
        p @madness
        if @user
            partial 'new'

        if @user
            partial 'logout'
        else
            partial 'login'    

    client '/contact.js': ->
        connect()
