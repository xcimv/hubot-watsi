# Description:
#   Find treatments to fund on Watsi.
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   watsi all - List all unfunded treatments
#   watsi almost [min <percentage|90>] - List treatments that are almost funded
#   watsi random - Get a random unfunded treatment
#
# Author:
#   xcimv

ALMOST_PERCENTAGE = 90

module.exports = (robot) ->
  robot.hear /watsi all/i, (msg) ->
    get_treatments msg, (treatments) ->
      subject = "#{treatments.length} treatment(s) are unfunded:"
      display_treatments msg, treatments, subject

  robot.hear /watsi almost( min ([0-9]{1,2})%?)?/i, (msg) ->
    get_treatments msg, (treatments) ->
      almost_percentage = if msg.match[2]? then parseInt(msg.match[2], 10) else ALMOST_PERCENTAGE
      almost = treatments
                 .filter (t) -> Math.floor(t.percent_funded * 100) >= almost_percentage
                 .sort (a, b) -> b.percent_funded - a.percent_funded

      if almost.length
        subject = "Treatments almost there (#{almost_percentage}% funded):"
        display_treatments msg, almost, subject
      else
        select_random_treatment treatments, (treatment) ->
          subject = "No treatments are close to funded, but here's a random one:"
          display_treatments msg, treatment, subject

  robot.hear /watsi random/i, (msg) ->
    get_treatments msg, (treatments) ->
      select_random_treatment treatments, (treatment) ->
        msg.send format_treatment(treatment)

  display_treatments = (msg, treatments, subject) ->
    treatments = [treatments] unless isArray treatments
    output = ""
    output += "#{subject}\n\n" if subject
    output += treatments.map(format_treatment).join("\n--\n")
    msg.send output

  format_treatment = (t) ->
    percent_funded = Math.floor(t.percent_funded * 100)
    amount_remaining =  t.amount_remaining / 100
    target_amount =  t.target_amount / 100

    output = "#{t.header} #{t.name} is #{percent_funded}% funded"
    output += " with $#{amount_remaining} USD left to reach $#{target_amount}.\n\n"
    output += "Fund #{t.name}'s treatment at #{t.url}"

    return output

  select_random_treatment = (treatments, cb) ->
    cb treatments[Math.floor(Math.random() * treatments.length)]

  get_treatments = (msg, cb) ->
    watsi_request msg, "/fund-treatments.json", (data) ->
      treatments = if data.profiles? then data.profiles else null
      if treatments == null
        msg.send "Error finding treatments"
      else if treatments.length
        cb treatments
      else
        msg.send "No treatments found requiring funding"

  watsi_request = (msg, path, cb) ->
    msg.http("https://watsi.org" + path)
      .headers("User-Agent": "hubot-watsi")
      .get() (err, res, body) ->
        if err
          msg.send "Watsi server error: #{err}"
          return
        try
          data = JSON.parse(body)
          cb data
        catch e
          msg.send "Error parsing the response: #{e.message}"
          return

  isArray = Array.isArray || (value) -> return {}.toString.call(value) is '[object Array]'
