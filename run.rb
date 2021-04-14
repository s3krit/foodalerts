# frozen_string_literal: true

require './foodalerts'

FoodAlerts::Jobs.scheduler.join
