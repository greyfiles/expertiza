class PasswordRetrievalController < ApplicationController
  def action_allowed?
    true
  end

  # Renders the password retrieval page
  def forgotten
    render template: 'password_retrieval/forgotten'
  end

  def send_password
    if params[:user][:email].nil? || params[:user][:email].strip.empty?
      flash[:error] = 'Please enter an e-mail address.'
    else
      user = User.find_by(email: params[:user][:email])
      if user
        url_format = '/password_edit/check_reset_url?token='
        token = SecureRandom.urlsafe_base64
        PasswordReset.save_token(user, token)
        url = request.base_url + url_format + token
        MailerHelper.send_mail_to_user(user, 'Expertiza password reset', 'send_password', url).deliver_now
        ExpertizaLogger.info LoggerMessage.new(controller_name, user.name, 'A link to reset your password has been sent to users e-mail address.', request)
        flash[:success] = 'A link to reset your password has been sent to your e-mail address.'
        redirect_to '/'
      else
        ExpertizaLogger.error LoggerMessage.new(controller_name, params[:user][:email], 'No user is registered with provided email id!', request)
        flash[:error] = 'No account is associated with the e-mail address: "' + params[:user][:email] + '". Please try again.'
        render template: 'password_retrieval/forgotten'
      end
    end
  end

  # Checks the request for a valid, unexpired password reset token
  def check_reset_url
    if params[:token].nil?
      # If token from the request params is nil, then flashes error message
      flash[:error] = 'Password reset page can only be accessed with a generated link, sent to your email'
      render template: 'password_retrieval/forgotten'
    else
      # Decrypts the token and searches for a matching token in the database
      @token = Digest::SHA1.hexdigest(params[:token])
      password_reset = PasswordReset.find_by(token: @token)
      if password_reset
        # URL expires after 1 day
        expired_url = password_reset.updated_at + 1.day
        if Time.now < expired_url
          # redirect_to action: 'reset_password', email: password_reset.user_email
          @email = password_reset.user_email
          render template: 'password_retrieval/reset_password'
        else
          ExpertizaLogger.error LoggerMessage.new(controller_name, '', 'User tried to use an expired link!', request)
          flash[:error] = 'Link expired . Please request to reset password again'
          render template: 'password_retrieval/forgotten'
        end
      else
        ExpertizaLogger.error LoggerMessage.new(controller_name, '', 'User tried to use the link with an invalid token!', request)
        flash[:error] = 'Link is invalid. Please request to reset password again'
        render template: 'password_retrieval/forgotten'
      end
    end
  end

  # Renders the password retrieval page with an error message
  def reset_password
    flash[:error] = 'Password reset page can only be accessed with a generated link, sent to your email'
    render template: 'password_retrieval/forgotten'
  end

  # Updates the user password and deletes all password reset tokens associated with the user email ID
  def update_password
    if params[:reset][:password] == params[:reset][:repassword]
      # If the password and password confirmation fields match, then updates the user password
      user = User.find_by(email: params[:reset][:email])
      user.password = params[:reset][:password]
      user.password_confirmation = params[:reset][:repassword]
      if user.save
        PasswordReset.delete_all(user_email: user.email) # Deletes all password reset tokens associated with the email ID of the user
        ExpertizaLogger.info LoggerMessage.new(controller_name, user.name, 'Password was reset for the user', request)
        flash[:success] = 'Password was successfully reset'
      else
        ExpertizaLogger.error LoggerMessage.new(controller_name, user.name, 'Password reset operation failed for the user while saving record', request)
        flash[:error] = 'Password cannot be updated. Please try again'
      end
      redirect_to '/'
    else
      # If the password and password confirmation fields don't match, then flashes error message
      ExpertizaLogger.error LoggerMessage.new(controller_name, '', 'Password provided by the user did not match', request)
      flash[:error] = 'Password and confirm-password do not match. Try again'
      @email = params[:reset][:email]
      render template: 'password_retrieval/reset_password'
    end
  end
end
