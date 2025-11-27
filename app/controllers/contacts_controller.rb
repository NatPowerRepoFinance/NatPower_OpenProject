# frozen_string_literal: true

class ContactsController < ApplicationController
  layout "admin"

  menu_item :contacts

  before_action :require_admin
  before_action :find_contact, only: %i[show edit update destroy]

  def index
    @contacts = Contact.ordered_by_name
  end

  def show; end

  def new
    @contact = Contact.new
  end

  def edit; end

  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to contacts_path
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_create_with_reason,
                                 reason: @contact.errors.full_messages.to_sentence)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @contact.update(contact_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to contacts_path
    else
      flash.now[:error] = I18n.t(:notice_unsuccessful_update_with_reason,
                                 reason: @contact.errors.full_messages.to_sentence)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @contact.destroy
      flash[:notice] = I18n.t(:notice_successful_delete)
    else
      flash[:error] = I18n.t(:notice_unsuccessful_delete)
    end

    redirect_to contacts_path, status: :see_other
  end

  private

  def find_contact
    @contact = Contact.find(params[:id])
  end

  def contact_params
    params.require(:contact).permit(
      :honorifics_id,
      :first_name,
      :last_name,
      :full_name,
      :email_work,
      :email_private,
      :phone,
      :mobile,
      :phone_alternative,
      :job_title,
      :date_of_birth,
      :is_deleted
    )
  end
end

