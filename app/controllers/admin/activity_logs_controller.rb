module Admin
  class ActivityLogsController < BaseController
    def index
      @logs = ActivityLog.includes(:user, :company).recent_first

      @logs = @logs.where(company_id: params[:company_id]) if params[:company_id].presence
      @logs = @logs.where(user_id: params[:user_id]) if params[:user_id].presence
      @logs = @logs.where(action: params[:action_type]) if params[:action_type].presence
      @logs = @logs.where(event_type: params[:event_type]) if params[:event_type].presence

      @logs = @logs.page(params[:page]).per(50)

      @companies = Company.order(:name)
      @users = User.order(:name)
    end
  end
end
