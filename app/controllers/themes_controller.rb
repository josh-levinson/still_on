# Saves the visitor's light/dark choice in a cookie, so it works for guests
# too. The theme_controller Stimulus controller applies it without a reload;
# this endpoint is the no-JS fallback and what makes the choice stick.
class ThemesController < ApplicationController
  def update
    theme = params[:theme].to_s

    if ApplicationHelper::THEMES.include?(theme)
      cookies.permanent[:theme] = { value: theme, same_site: :lax }
    else
      cookies.delete(:theme)
    end

    redirect_back_or_to root_path
  end
end
