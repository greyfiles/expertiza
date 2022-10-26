class PasswordRetrievalController < ApplicationController
  def action_allowed?
    true
  end

  # Renders the password retrieval page
  def forgotten
    render template: 'password_retrieval/forgotten'
  end

  # on click of request password button, sends a password reset url with a randomly generated token parameter to an authenticated user email
  def send_password
    if params[:user][:email].nil? || params[:user][:email].strip.empty?
      flash[:error] = 'Please enter an e-mail address.'
      render template: 'password_retrieval/forgotten'
    else
      user = User.find_by(email: params[:user][:email])
      if user
        # formats password reset url to include a queryable token parameter 
        url_format = '/password_edit/check_token_validity?token='
        # generates a random URL-safe base64 token with default length of 16 characters
        token = SecureRandom.urlsafe_base64
        PasswordReset.save_token(user, token)
        url = request.base_url + url_format + token
        # delivers formatted password reset url to a valid user email
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
  def check_token_validity
    days_until_token_expiration = 1

    if params[:token].nil?
      require_password_reset_token
    else
      # Decrypts the token and searches for a matching token in the database
      @token = Digest::SHA1.hexdigest(params[:token])
      password_reset = PasswordReset.find_by(token: @token)
      if password_reset
        # URL expires after 1 day
        expired_url = password_reset.updated_at + days_until_token_expiration.day
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
    require_password_reset_token
  end

  # Updates the user password and invalidates reset tokens associated with the user email ID
  def update_password
    # Performs confirm password validation to catch user typos
    if params[:reset][:password] == params[:reset][:repassword]
      user = User.find_by(email: params[:reset][:email])
      user.password = params[:reset][:password]
      user.password_confirmation = params[:reset][:repassword]
      if user.save
        # Deletes all password reset tokens of the user to invalidate the used and previous tokens
        PasswordReset.delete_all(user_email: user.email)
        ExpertizaLogger.info LoggerMessage.new(controller_name, user.name, 'Password was reset for the user', request)
        flash[:success] = 'Password was successfully reset'
      else
        ExpertizaLogger.error LoggerMessage.new(controller_name, user.name, 'Password reset operation failed for the user while saving record', request)
        flash[:error] = 'Password cannot be updated. Please try again'
      end
      redirect_to '/'
    else
      ExpertizaLogger.error LoggerMessage.new(controller_name, '', 'Password provided by the user did not match', request)
      flash[:error] = 'Password and confirm-password do not match. Try again'
      @email = params[:reset][:email]
      render template: 'password_retrieval/reset_password'
    end
  end

  def require_password_reset_token
    flash[:error] = 'Password reset page can only be accessed with a generated link, sent to your email'
    render template: 'password_retrieval/forgotten'
  end
    
end
