# frozen_string_literal: true

require "test_helper"

class Tic::Tac::TestToe < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Tic::Tac::Toe::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end
