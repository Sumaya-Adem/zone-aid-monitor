CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "plpgsql" WITH SCHEMA "pg_catalog";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
BEGIN;

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: aid_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.aid_type AS ENUM (
    'water',
    'food',
    'health',
    'cash'
);


--
-- Name: app_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.app_role AS ENUM (
    'admin',
    'ngo_user'
);


--
-- Name: area_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.area_status AS ENUM (
    'not_aided',
    'partially_aided',
    'fully_aided'
);


--
-- Name: report_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.report_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'flagged'
);


--
-- Name: get_user_organization_id(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_organization_id(_user_id uuid) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT organization_id
  FROM public.profiles
  WHERE user_id = _user_id
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', '')
  );
  RETURN NEW;
END;
$$;


--
-- Name: has_role(uuid, public.app_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_role(_user_id uuid, _role public.app_role) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;


--
-- Name: notify_admins_new_report(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_admins_new_report() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    admin_user RECORD;
    org_name TEXT;
    area_name TEXT;
BEGIN
    -- Get organization name
    SELECT name INTO org_name FROM public.organizations WHERE id = NEW.organization_id;
    
    -- Get area name
    SELECT village || ', ' || district INTO area_name FROM public.areas WHERE id = NEW.area_id;
    
    -- Notify all admins
    FOR admin_user IN 
        SELECT user_id FROM public.user_roles WHERE role = 'admin'
    LOOP
        INSERT INTO public.notifications (user_id, title, message, type, related_record_id)
        VALUES (
            admin_user.user_id,
            'New Report Submitted',
            'A new ' || NEW.aid_type || ' aid report has been submitted by ' || COALESCE(org_name, 'Unknown') || ' for ' || COALESCE(area_name, 'Unknown area'),
            'new_report_submitted',
            NEW.id
        );
    END LOOP;
    
    RETURN NEW;
END;
$$;


--
-- Name: notify_ngo_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_ngo_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    notification_title TEXT;
    notification_message TEXT;
    notification_type TEXT;
    area_name TEXT;
BEGIN
    -- Only trigger on status change
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        -- Get area name
        SELECT village || ', ' || district INTO area_name FROM public.areas WHERE id = NEW.area_id;
        
        IF NEW.status = 'approved' THEN
            notification_title := 'Report Approved';
            notification_message := 'Your ' || NEW.aid_type || ' aid report for ' || COALESCE(area_name, 'Unknown area') || ' has been approved.';
            notification_type := 'report_approved';
        ELSIF NEW.status = 'rejected' THEN
            notification_title := 'Report Rejected';
            notification_message := 'Your ' || NEW.aid_type || ' aid report for ' || COALESCE(area_name, 'Unknown area') || ' has been rejected. Reason: ' || COALESCE(NEW.rejection_reason, 'No reason provided');
            notification_type := 'report_rejected';
        ELSIF NEW.status = 'flagged' THEN
            notification_title := 'Report Flagged';
            notification_message := 'Your ' || NEW.aid_type || ' aid report for ' || COALESCE(area_name, 'Unknown area') || ' has been flagged for review. Reason: ' || COALESCE(NEW.flag_reason, 'No reason provided');
            notification_type := 'report_flagged';
        ELSE
            RETURN NEW;
        END IF;
        
        -- Notify the report creator
        IF NEW.created_by IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, message, type, related_record_id, admin_notes)
            VALUES (
                NEW.created_by,
                notification_title,
                notification_message,
                notification_type,
                NEW.id,
                CASE 
                    WHEN NEW.status = 'rejected' THEN NEW.rejection_reason
                    WHEN NEW.status = 'flagged' THEN NEW.flag_reason
                    ELSE NULL
                END
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


SET default_table_access_method = heap;

--
-- Name: admin_action_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_action_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aid_record_id uuid NOT NULL,
    admin_id uuid NOT NULL,
    action text NOT NULL,
    previous_status public.report_status,
    new_status public.report_status,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: aid_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aid_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    area_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    created_by uuid,
    aid_type public.aid_type NOT NULL,
    quantity integer NOT NULL,
    unit text NOT NULL,
    delivery_date date NOT NULL,
    notes text,
    is_duplicate_warning boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status public.report_status DEFAULT 'pending'::public.report_status NOT NULL,
    beneficiary_count integer,
    field_officer_name text,
    rejection_reason text,
    approved_at timestamp with time zone,
    approved_by uuid,
    flagged boolean DEFAULT false,
    flag_reason text
);


--
-- Name: aid_restriction_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aid_restriction_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aid_type public.aid_type NOT NULL,
    restriction_days integer NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.areas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    area_id text NOT NULL,
    country text NOT NULL,
    region text NOT NULL,
    district text NOT NULL,
    village text NOT NULL,
    latitude numeric(10,8),
    longitude numeric(11,8),
    population integer,
    status public.area_status DEFAULT 'not_aided'::public.area_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: duplicate_warnings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.duplicate_warnings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aid_record_id uuid NOT NULL,
    previous_record_id uuid NOT NULL,
    warning_reason text NOT NULL,
    acknowledged boolean DEFAULT false NOT NULL,
    acknowledged_by uuid,
    acknowledged_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    type text NOT NULL,
    related_record_id uuid,
    is_read boolean DEFAULT false NOT NULL,
    admin_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notifications_type_check CHECK ((type = ANY (ARRAY['report_approved'::text, 'report_rejected'::text, 'report_flagged'::text, 'new_report_submitted'::text])))
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    contact_email text,
    contact_phone text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    organization_id uuid,
    full_name text,
    email text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: report_evidence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_evidence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aid_record_id uuid NOT NULL,
    file_url text NOT NULL,
    file_name text NOT NULL,
    file_type text,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role public.app_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_action_logs admin_action_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_action_logs
    ADD CONSTRAINT admin_action_logs_pkey PRIMARY KEY (id);


--
-- Name: aid_records aid_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_records
    ADD CONSTRAINT aid_records_pkey PRIMARY KEY (id);


--
-- Name: aid_restriction_rules aid_restriction_rules_aid_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_restriction_rules
    ADD CONSTRAINT aid_restriction_rules_aid_type_key UNIQUE (aid_type);


--
-- Name: aid_restriction_rules aid_restriction_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_restriction_rules
    ADD CONSTRAINT aid_restriction_rules_pkey PRIMARY KEY (id);


--
-- Name: areas areas_area_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_area_id_key UNIQUE (area_id);


--
-- Name: areas areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_pkey PRIMARY KEY (id);


--
-- Name: duplicate_warnings duplicate_warnings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_warnings
    ADD CONSTRAINT duplicate_warnings_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_name_key UNIQUE (name);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);


--
-- Name: report_evidence report_evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_evidence
    ADD CONSTRAINT report_evidence_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_user_id_role_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_role_key UNIQUE (user_id, role);


--
-- Name: aid_records on_aid_record_created; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_aid_record_created AFTER INSERT ON public.aid_records FOR EACH ROW EXECUTE FUNCTION public.notify_admins_new_report();


--
-- Name: aid_records on_aid_record_status_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_aid_record_status_change AFTER UPDATE ON public.aid_records FOR EACH ROW EXECUTE FUNCTION public.notify_ngo_status_change();


--
-- Name: aid_records update_aid_records_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_aid_records_updated_at BEFORE UPDATE ON public.aid_records FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: aid_restriction_rules update_aid_restriction_rules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_aid_restriction_rules_updated_at BEFORE UPDATE ON public.aid_restriction_rules FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: areas update_areas_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_areas_updated_at BEFORE UPDATE ON public.areas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: organizations update_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: profiles update_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: admin_action_logs admin_action_logs_aid_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_action_logs
    ADD CONSTRAINT admin_action_logs_aid_record_id_fkey FOREIGN KEY (aid_record_id) REFERENCES public.aid_records(id) ON DELETE CASCADE;


--
-- Name: aid_records aid_records_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_records
    ADD CONSTRAINT aid_records_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE CASCADE;


--
-- Name: aid_records aid_records_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_records
    ADD CONSTRAINT aid_records_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: aid_records aid_records_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_records
    ADD CONSTRAINT aid_records_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: aid_restriction_rules aid_restriction_rules_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aid_restriction_rules
    ADD CONSTRAINT aid_restriction_rules_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: duplicate_warnings duplicate_warnings_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_warnings
    ADD CONSTRAINT duplicate_warnings_acknowledged_by_fkey FOREIGN KEY (acknowledged_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: duplicate_warnings duplicate_warnings_aid_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_warnings
    ADD CONSTRAINT duplicate_warnings_aid_record_id_fkey FOREIGN KEY (aid_record_id) REFERENCES public.aid_records(id) ON DELETE CASCADE;


--
-- Name: duplicate_warnings duplicate_warnings_previous_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_warnings
    ADD CONSTRAINT duplicate_warnings_previous_record_id_fkey FOREIGN KEY (previous_record_id) REFERENCES public.aid_records(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_related_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_related_record_id_fkey FOREIGN KEY (related_record_id) REFERENCES public.aid_records(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: report_evidence report_evidence_aid_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_evidence
    ADD CONSTRAINT report_evidence_aid_record_id_fkey FOREIGN KEY (aid_record_id) REFERENCES public.aid_records(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: aid_records Admins can delete any aid_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can delete any aid_records" ON public.aid_records FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: organizations Admins can delete organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can delete organizations" ON public.organizations FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: user_roles Admins can delete roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can delete roles" ON public.user_roles FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: admin_action_logs Admins can insert action logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert action logs" ON public.admin_action_logs FOR INSERT WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: aid_records Admins can insert any aid_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert any aid_records" ON public.aid_records FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: report_evidence Admins can insert any evidence; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert any evidence" ON public.report_evidence FOR INSERT WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: organizations Admins can insert organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert organizations" ON public.organizations FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: profiles Admins can insert profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert profiles" ON public.profiles FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: user_roles Admins can insert roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert roles" ON public.user_roles FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: duplicate_warnings Admins can manage warnings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can manage warnings" ON public.duplicate_warnings TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: profiles Admins can update all profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update all profiles" ON public.profiles FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: aid_records Admins can update any aid_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update any aid_records" ON public.aid_records FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: areas Admins can update areas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update areas" ON public.areas FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: organizations Admins can update organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update organizations" ON public.organizations FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: user_roles Admins can update roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update roles" ON public.user_roles FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: aid_restriction_rules Admins can update rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update rules" ON public.aid_restriction_rules FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: admin_action_logs Admins can view all action logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can view all action logs" ON public.admin_action_logs FOR SELECT USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: organizations Admins can view all organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can view all organizations" ON public.organizations FOR SELECT USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: profiles Admins can view all profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: user_roles Admins can view all roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can view all roles" ON public.user_roles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'::public.app_role));


--
-- Name: aid_records Anyone authenticated can view aid_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone authenticated can view aid_records" ON public.aid_records FOR SELECT TO authenticated USING (true);


--
-- Name: areas Anyone authenticated can view areas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone authenticated can view areas" ON public.areas FOR SELECT TO authenticated USING (true);


--
-- Name: aid_restriction_rules Anyone authenticated can view rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone authenticated can view rules" ON public.aid_restriction_rules FOR SELECT TO authenticated USING (true);


--
-- Name: duplicate_warnings Anyone authenticated can view warnings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone authenticated can view warnings" ON public.duplicate_warnings FOR SELECT TO authenticated USING (true);


--
-- Name: areas Authenticated users can insert areas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can insert areas" ON public.areas FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: report_evidence NGO users can insert evidence for their org reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "NGO users can insert evidence for their org reports" ON public.report_evidence FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.aid_records ar
  WHERE ((ar.id = report_evidence.aid_record_id) AND (ar.organization_id = public.get_user_organization_id(auth.uid()))))));


--
-- Name: aid_records NGO users can insert their org aid_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "NGO users can insert their org aid_records" ON public.aid_records FOR INSERT TO authenticated WITH CHECK (((organization_id = public.get_user_organization_id(auth.uid())) AND (created_by = auth.uid())));


--
-- Name: duplicate_warnings NGO users can insert warnings for their org records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "NGO users can insert warnings for their org records" ON public.duplicate_warnings FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.aid_records ar
  WHERE ((ar.id = duplicate_warnings.aid_record_id) AND (ar.organization_id = public.get_user_organization_id(auth.uid()))))));


--
-- Name: areas NGO users can update areas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "NGO users can update areas" ON public.areas FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'ngo_user'::public.app_role));


--
-- Name: aid_records NGO users can update their own aid_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "NGO users can update their own aid_records" ON public.aid_records FOR UPDATE TO authenticated USING (((created_by = auth.uid()) AND (organization_id = public.get_user_organization_id(auth.uid()))));


--
-- Name: notifications Only system can create notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only system can create notifications" ON public.notifications FOR INSERT WITH CHECK (false);


--
-- Name: notifications Users can update their own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE USING ((user_id = auth.uid()));


--
-- Name: profiles Users can update their own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING ((user_id = auth.uid()));


--
-- Name: report_evidence Users can view evidence for their org reports or admins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view evidence for their org reports or admins" ON public.report_evidence FOR SELECT USING ((public.has_role(auth.uid(), 'admin'::public.app_role) OR (EXISTS ( SELECT 1
   FROM public.aid_records ar
  WHERE ((ar.id = report_evidence.aid_record_id) AND (ar.organization_id = public.get_user_organization_id(auth.uid())))))));


--
-- Name: notifications Users can view their own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: organizations Users can view their own organization; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own organization" ON public.organizations FOR SELECT USING ((id = public.get_user_organization_id(auth.uid())));


--
-- Name: profiles Users can view their own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: user_roles Users can view their own roles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own roles" ON public.user_roles FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: admin_action_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_action_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: aid_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aid_records ENABLE ROW LEVEL SECURITY;

--
-- Name: aid_restriction_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aid_restriction_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: areas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;

--
-- Name: duplicate_warnings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.duplicate_warnings ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: organizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: report_evidence; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_evidence ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--




COMMIT;