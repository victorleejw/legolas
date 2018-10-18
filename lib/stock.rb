class Stock
  def self.price_cents(symbol)
    url = "https://api.iextrading.com/1.0/stock/#{symbol.downcase}/price"
    res = HTTParty.get(url).parsed_response
    return nil unless res.is_a?(Numeric)
    (res * 100).round
  end

  def self.info(symbol)
    symbol = symbol.upcase
    lwrSymbol = symbol.downcase
    stock = {}
    stock.merge!(charts(symbol))
    iexCompanyURL = "https://api.iextrading.com/1.0/stock/#{lwrSymbol}/company"
    iexCompany = HTTParty.get(iexCompanyURL).parsed_response
    unless iexCompany == "Unknown symbol"
      stock.merge!(iexCompany.slice("companyName", "description"))
    end
    stock
  end

  def self.charts(symbol, key_by_time: false, clear_zeroes: true)
    symbol = symbol.upcase
    lwrSymbol = symbol.downcase
    stock = { symbol: symbol }
    iexDayURL = "https://api.iextrading.com/1.0/stock/#{lwrSymbol}/chart/1d"
    iexDay = HTTParty.get(iexDayURL).parsed_response
    return nil if iexDay == "Unknown symbol"
    fiveYearURL = "https://api.iextrading.com/1.0/stock/#{lwrSymbol}/chart/5y"
    iexFiveYear = HTTParty.get(fiveYearURL).parsed_response
    return nil if iexFiveYear == "Unknown symbol"
    stock.merge!(charts_from_iex_data(
      iexDay,
      iexFiveYear,
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    ))
  end

  def self.day_chart(symbol, key_by_time: false, clear_zeroes: true)
    symbol = symbol.upcase
    lwrSymbol = symbol.downcase
    stock = { symbol: symbol }
    iexDayURL = "https://api.iextrading.com/1.0/stock/#{lwrSymbol}/chart/1d"
    iexDay = HTTParty.get(iexDayURL).parsed_response
    return nil if iexDay == "Unknown symbol"
    stock.merge!(process_day(
      iexDay,
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    ))
  end

  def self.five_years_charts(symbol, key_by_time: false, clear_zeroes: true)
    symbol = symbol.upcase
    lwrSymbol = symbol.downcase
    stock = { symbol: symbol }
    fiveYearURL = "https://api.iextrading.com/1.0/stock/#{lwrSymbol}/chart/5y"
    iexFiveYear = HTTParty.get(fiveYearURL).parsed_response
    return nil if iexFiveYear == "Unknown symbol"
    stock.merge!(process_five_years(
      iexFiveYear,
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    ))
  end

  def self.detailed_week_chart(symbol, key_by_time: false, clear_zeroes: true)
    symbol = symbol.upcase
    stock = { symbol: symbol }
    weekURL = "https://www.alphavantage.co/query" +
              "?function=TIME_SERIES_INTRADAY&symbol=#{symbol}&interval=5min" +
              "&apikey=#{ENV["ALPHA_VANTAGE_API_KEY"]}&outputsize=full"
    res = HTTParty.get(weekURL).parsed_response
    return nil unless res.key?("Time Series (5min)")
    stock.merge!(process_week(
      res["Time Series (5min)"],
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    ))
  end

  private

  def self.charts_from_iex_data(
    iexDay,
    iexFiveYear,
    key_by_time: false,
    clear_zeroes: true
  )
    process_day(
      iexDay,
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    ).merge!(process_five_years(
      iexFiveYear,
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    ))
  end

  def self.process_day(iexDay, key_by_time: false, clear_zeroes: true)
    {
      price_cents: (most_recent_close(iexDay).to_f * 100).round,
      "1D" => extract_times(
        iexDay,
        divisor: 5,
        key_by_time: key_by_time,
        clear_zeroes: clear_zeroes
      )
    }
  end

  def self.process_five_years(
    iexFiveYear,
    key_by_time: false,
    clear_zeroes: true
  )
    week_chart = extract_days(
      iexFiveYear,
      1,
      5,
      by_count: true,
      key_by_time: key_by_time,
      clear_zeroes: clear_zeroes
    )
    week_chart[:detailed] = false
    {
      "1W" => week_chart,
      "1M" => extract_days(
        iexFiveYear,
        1,
        30,
        key_by_time: key_by_time,
        clear_zeroes: clear_zeroes
      ),
      "3M" => extract_days(
        iexFiveYear,
        1,
        90,
        key_by_time: key_by_time,
        clear_zeroes: clear_zeroes
      ),
      "1Y" => extract_days(
        iexFiveYear,
        1,
        365,
        key_by_time: key_by_time,
        clear_zeroes: clear_zeroes
      ),
      "5Y" => extract_days(
        iexFiveYear,
        7,
        1_826,
        key_by_time: key_by_time,
        clear_zeroes: clear_zeroes
      )
    }
  end

  def self.most_recent_close(iexDay)
    close = nil
    i = -1
    until close || i.abs > iexDay.length
      close = iexDay[i]["close"] || iexDay[i]["marketClose"] || nil
      i -= 1
    end
    close
  end

  def self.process_week(week, key_by_time: false, clear_zeroes: true)
    points = []
    points = {} if key_by_time
    min = "dataMin"
    max = "dataMax"
    prev_time = nil
    days = 0
    current_day = nil
    week.each.with_index do |(datetime, data), i|
      time = parse_av_datetime(datetime)
      days += 1 if prev_time.nil? || time.day != prev_time.day
      if days > 5
        max = prev_time.to_i * 1000
        break
      end
      prev_time = time
      open_str = data["1. open"] || nil
      next if clear_zeroes && open_str.nil?
      price = (open_str.to_f * 100).round
      next if clear_zeroes && price.zero?
      time_int = time.to_i * 1_000
      if key_by_time
        points[time_int] = { price_cents: price, time: time_int }
      else
        points.unshift({ price_cents: price, time: time.to_i * 1000 })
      end
      min = time.to_i * 1_000 if i == 0
    end
    { "1W" => { min: min, max: max, points: points, detailed: true } }
  end

  def self.extract_times(
    time_series,
    divisor: 1,
    key_by_time: false,
    clear_zeroes: true
  )
    points = []
    points = {} if key_by_time
    time_series.each_with_index do |data, i|
      next unless i % divisor == 0
      close = data["close"] || data["marketClose"] || nil
      next if clear_zeroes && close.nil?
      time = parse_datetime(data).to_i * 1000
      price = (close.to_f * 100).round
      next if clear_zeroes && price.zero?
      if key_by_time
        points[time] = { price_cents: price, time: time }
      else
        points << { price_cents: price, time: time }
      end
    end
    d = Time.now.getlocal("-04:00")
    d = d.yesterday if ([d.hour, d.min] <=> [9, 30]) == -1
    min = Time.new(d.year, d.month, d.day, 9, 30, 0, "-04:00")
    max = Time.new(d.year, d.month, d.day, 15, 55, 0, "-04:00")
    { min: min.to_i * 1000, max: max.to_i * 1000, points: points }
  end

  def self.extract_days(
    day_series,
    divisor,
    days,
    by_count: false,
    key_by_time: false,
    clear_zeroes: true
  )
    points = []
    points = {} if key_by_time
    first = true
    first_day = nil
    min = days.days.ago
    day_series.reverse_each.with_index do |data, i|
      date = parse_date(data["date"])
      if first
        first_day = date
        first = false
      end
      day_count = ((first_day - date) / 86400).round
      day_count = i + 1 if by_count
      next unless day_count % divisor == 0
      time = date.to_i * 1000
      price = (data["close"].to_f * 100).round
      unless clear_zeroes && price == 0
        if key_by_time
          points[time] = { price_cents: price, time: time }
        else
          points.unshift({ price_cents: price, time: time })
        end
      end
      if day_count >= days
        min = date
        break
      end
    end
    { max: first_day.to_i * 1000, min: min.to_i * 1000, points: points }
  end

  def self.parse_datetime(data)
    args = [data["date"][0..3], data["date"][4..5], data["date"][6..7]]
    args += data["minute"].split(":")
    args << "00"
    args << "-04:00"
    Time.new(*args)
  end

  def self.parse_date(date)
    Time.new(*date.split("-").map(&:to_i), 16, 0, 0, "-04:00")
  end

  def self.parse_av_datetime(datetime)
    Time.new(*datetime.split(/[- :]/), "-04:00") - 5.minutes
  end
end
