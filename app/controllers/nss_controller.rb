class NssController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[add_host add_user_to_group]
  before_action :authenticate_access_token!, only: %i[add_host]

  def host
    token = AccessToken.valid_token params[:token]
    @response = nil
    if token
      @response = HostMachine.get_group_response(params[:name]) if params[:name].present?
      render json: @response
      return
    end

    host_machine = HostMachine.find_by(access_key: params[:token])
    sysadmins = host_machine.sysadmins if host_machine.present?
    if sysadmins.present? && sysadmins.count.positive?
      @response = Group.get_sysadmins_and_groups sysadmins, host_machine.default_admins
    end
    render json: @response
    nil
  end

  def add_host
    if params[:name].present?
      host = HostMachine.find_or_create_by(name: params[:name])
      host.default_admins = params[:default_admins]
      host.save
      host.add_host_group(params[:name])
      host.add_group(params[:group_name])
      render 'add_host', locals: { host: host }, format: :json
    else
      errors = ['Name can\'t be blank']
      if params.key?(:group_name) && params[:group_name].blank?
        errors << 'Group Name can\'t be blank'
      end
      render_error(errors)
    end
  end

  def group
    name = params[:name]
    gid = params[:gid]
    if name.present?
      @response = REDIS_CACHE.get("#{GROUP_NSS_RESPONSE}:#{params[:token]}#{name}")
      @response = JSON.parse(@response) if @response.present?
      if @response.blank?
        host_machine = HostMachine.find_by(access_key: params[:token])
        if host_machine.present?
          group = Group.get_name_response name
          @response = group.to_json
          REDIS_CACHE.set("#{GROUP_NSS_RESPONSE}:#{params[:token]}#{name}", @response)
          REDIS_CACHE.expire("#{GROUP_NSS_RESPONSE}:#{params[:token]}#{name}", REDIS_KEY_EXPIRY)
        end
      end
    elsif gid.present?
      @response = REDIS_CACHE.get("#{GROUP_NSS_RESPONSE}:#{params[:token]}#{gid}")
      @response = JSON.parse(@response) if @response.present?
      if @response.blank?
        host_machine = HostMachine.find_by(access_key: params[:token])
        if host_machine.present?
          group = Group.get_gid_response(gid)
          @response = group.to_json
          REDIS_CACHE.set("#{GROUP_NSS_RESPONSE}:#{params[:token]}#{gid}", @response)
          REDIS_CACHE.expire("#{GROUP_NSS_RESPONSE}:#{params[:token]}#{gid}", REDIS_KEY_EXPIRY)
        end
      end
    else
      @response = REDIS_CACHE.get("#{GROUP_RESPONSE}:#{params[:token]}")
      @response = JSON.parse(@response) if @response.present?
      if @response.blank?
        host_machine = HostMachine.find_by(access_key: params[:token])
        sysadmins = host_machine.sysadmins if host_machine.present?
        if sysadmins.present? && sysadmins.count.positive?
          @response = Group.get_sysadmins_and_groups(sysadmins, host_machine.default_admins, host_machine["id"])
          REDIS_CACHE.set("#{GROUP_RESPONSE}:#{params[:token]}", @response.to_json)
          REDIS_CACHE.expire("#{GROUP_RESPONSE}:#{params[:token]}", REDIS_KEY_EXPIRY)
        end
      end
    end
    render json: @response
  end

  def passwd
    name = params[:name]
    uid = params[:uid]
    if name.present?
      @response = REDIS_CACHE.get("#{PASSWD_RESPONSE}:#{params[:token]}#{name}")
      @response = JSON.parse(@response) if @response.present?
      if @response.blank?
        host_machine = HostMachine.find_by(access_key: params[:token])
        sysadmins = host_machine.sysadmins if host_machine.present?
        if sysadmins.present? && sysadmins.count.positive?
          user = User.get_user_sysadmin(sysadmins, name)
          @response = user.first
          REDIS_CACHE.set("#{PASSWD_RESPONSE}:#{params[:token]}#{name}", @response.to_json)
          REDIS_CACHE.expire("#{PASSWD_RESPONSE}:#{params[:token]}#{name}", REDIS_KEY_EXPIRY)
        end
      end
    elsif uid.present?
      @response = REDIS_CACHE.get("#{PASSWD_RESPONSE}:#{params[:token]}#{uid}")
      @response = JSON.parse(@response) if @response.present?
      if @response.blank?
        host_machine = HostMachine.find_by(access_key: params[:token])
        sysadmins = host_machine.sysadmins if host_machine.present?
        if sysadmins.present? && sysadmins.count.positive?
          user = User.get_user_by_uid uid
          @response = user.first
          REDIS_CACHE.set("#{PASSWD_RESPONSE}:#{params[:token]}#{uid}", @response.to_json)
          REDIS_CACHE.expire("#{PASSWD_RESPONSE}:#{params[:token]}#{uid}", REDIS_KEY_EXPIRY)
        end
      end
    else
      @response = REDIS_CACHE.get("#{PASSWD_RESPONSE}:#{params[:token]}")
      @response = JSON.parse(@response) if @response.present?
      if @response.blank?
        host_machine = HostMachine.find_by(access_key: params[:token])
        sysadmins = host_machine.sysadmins if host_machine.present?
        if sysadmins.present? && sysadmins.count.positive?
          @response = User.get_sysadmins(sysadmins)
          REDIS_CACHE.set("#{PASSWD_RESPONSE}:#{params[:token]}", @response.to_json)
          REDIS_CACHE.expire("#{PASSWD_RESPONSE}:#{params[:token]}", REDIS_KEY_EXPIRY)
        end
      end
    end
    render json: @response
  end

  def shadow
    host_machine = HostMachine.find_by(access_key: params[:token])
    @response = nil

    if host_machine.present?
      name = params[:name]

      if name.present?
        @response = REDIS_CACHE.get(SHADOW_NAME_RESPONSE + name)
        if @response.blank?
          @response = User.get_shadow_name_response(name).to_json
          REDIS_CACHE.set(SHADOW_NAME_RESPONSE + name, @response)
          REDIS_CACHE.expire(SHADOW_NAME_RESPONSE + name, REDIS_KEY_EXPIRY)
        end
      else
        @response = REDIS_CACHE.get(SHADOW_ALL_RESPONSE)
        if @response.blank?
          @response = User.get_all_shadow_response.to_json
          REDIS_CACHE.set(SHADOW_ALL_RESPONSE, @response)
          REDIS_CACHE.expire(SHADOW_ALL_RESPONSE, REDIS_KEY_EXPIRY)
        end
      end
    end
    render json: @response
  end

  def groups_list
    token = AccessToken.valid_token params[:token]
    if token
      user = User.get_user(params[:email].split('@').first)
      if user.blank?
        render json: { success: false }
      else
        groups = user.blank? ? [] : user.group_names_list
        render json: { success: true, groups: groups }
      end
    else
      render json: { success: false }
    end
  end
end
