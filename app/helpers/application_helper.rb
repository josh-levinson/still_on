module ApplicationHelper
  def google_calendar_url(event_occurrence, event)
    start_utc = event_occurrence.start_time.utc.strftime("%Y%m%dT%H%M%SZ")
    end_utc   = event_occurrence.end_time.utc.strftime("%Y%m%dT%H%M%SZ")
    params = { action: "TEMPLATE", text: event.title, dates: "#{start_utc}/#{end_utc}" }
    params[:location] = event_occurrence.location if event_occurrence.location.present?
    params[:details]  = event_occurrence.notes    if event_occurrence.notes.present?
    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end
end
