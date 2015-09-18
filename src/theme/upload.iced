
helpers = require('../helpers')

inquirer = require("inquirer")
colors = require('colors')
fs = require('fs')
path = require('path')
request = require('request')
mkdirp = require('mkdirp')
walk = require('walk')
parser = require('gitignore-parser')

exports.run = (argv, done) ->

  filter = _.first(argv['_'])

  await helpers.loadConfig(defer(err, config))
  if err? then done(err)

  if config.ignore_file
    ignore = parser.compile(fs.readFileSync(config.ignore_file, 'utf8'))

  await helpers.getTarget(config, argv, defer(err, target))
  if err? then return done(err)

  walker = walk.walk(path.join(process.cwd(), 'theme'), { followLinks: false })

  walker.on("file", (root, fileStat, next) ->
    # filepath = path.join(root, fileStat.name).replace(process.cwd()+"/theme/", "")
    filepath = path.join(root, fileStat.name)
    pathParts = filepath.split(path.sep)
    trimmedParts = _.drop(pathParts, (_.lastIndexOf(pathParts, 'theme') + 1))
    filepath = trimmedParts.join(path.sep)

    # Ignore hidden files
    if filepath.match(/^\..*$/) then return next()

    # Ignore paths configured in ignore file
    if config.ignore_file
      if ignore.denies(filepath) then return next()

    if filter? and not filepath.match(new RegExp("^#{filter}")) then return next()

    extension = path.extname(filepath).substr(1)

    next()

    if filepath.match(/[\(\)]/)
      return helpers.log("Filename may not contain parentheses, please rename - \"#{filepath}\"", 'red')

    await fs.readFile(path.join('theme', filepath), defer(err, data))
    if err? then helpers.log(err, 'red')

    await helpers.shopifyRequest({
      filepath: filepath.split(path.sep).join('/')
      method: 'put'
      url: "https://#{target.api_key}:#{target.password}@#{target.domain}.myshopify.com/admin/themes/#{target.theme_id}/assets.json"
      json: {
        asset: {
          key: filepath.split(path.sep).join('/')
          attachment: data.toString('base64')
        }
      }
    }, defer(err, res, assetsBody))
    if err? then helpers.log(err, 'red')

    unless err? then helpers.log("Uploaded #{filepath}", 'green')
  )
