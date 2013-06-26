ioModule = require("socket.io")
async = require("async")
request = require("request")
fs = require("fs")
config = require "../config/config"
config.setEnvironment process.env.NODE_ENV
###
JSON parser
to save only cards only from official chapter list
###

get = (server)->
  io = ioModule.listen(server)
  async.forever ((callback) ->
    official_chapter_list = 'https://api.trello.com/1/lists/51c19fb532a9eb417100309d?cards=open&fields=name&card_fields=desc&key=4e2912efa3fa9e7a92d0557055ca3aa2'
    request official_chapter_list, (error, response, body)->
      unless error
        newcontacts = {}
        try
          chapter_cards = JSON.parse body
          cards = chapter_cards.cards
          #console.log cards
          for card in cards
            #console.log card
            obj = {}
            if card.desc isnt ''
              descriptions = card.desc.split '\n'
              for description in descriptions
                descvalue = description.split "**"
                if descvalue[1]?
                  descvalue[1] = descvalue[1].substr(0, descvalue[1].length - 1)
                  obj[descvalue[1]] = descvalue[2].replace(/^\s+|\s+$/g, "")
                  card.desc = obj
              newcontacts[cards.indexOf(card)] = card
          
          
          io.sockets.on "connection", (socket) ->
            console.log 'socket connected'
            socket.emit "change",
              message: "changed"
              file: newcontacts
          fs.readFile "./data/chapters.json", (err, oldcontacts)->
            if err
              console.log "cannot read file ./data/chapters.json", err
              throw err
            else
              jsonString = JSON.stringify(newcontacts,null,2)
              oldjson = JSON.parse(oldcontacts)
              oldjsonString = JSON.stringify(oldjson,null,2)
              console.log("Is new file equals old file?: ", jsonString is oldjsonString);
              if jsonString isnt oldjsonString
                # console.log JSON.parse jsonString
                  fs.writeFile "./data/chapters.json", jsonString, (err) ->
                    unless err
                      console.log "Official chapter list saved"
                    else
                      console.log err
              else
                console.log("nothing to to update");
        
        catch e
          console.log "Invalid JSON format error: ", e
          throw e          
  ), (err) ->
    console.log err  if err

getCards = ()->
  setInterval(get, config.PARSE_INTERVAL)

exports = module.exports = getCards