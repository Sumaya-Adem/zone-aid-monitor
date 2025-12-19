export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      admin_action_logs: {
        Row: {
          action: string
          admin_id: string
          aid_record_id: string
          created_at: string
          id: string
          new_status: Database["public"]["Enums"]["report_status"] | null
          notes: string | null
          previous_status: Database["public"]["Enums"]["report_status"] | null
        }
        Insert: {
          action: string
          admin_id: string
          aid_record_id: string
          created_at?: string
          id?: string
          new_status?: Database["public"]["Enums"]["report_status"] | null
          notes?: string | null
          previous_status?: Database["public"]["Enums"]["report_status"] | null
        }
        Update: {
          action?: string
          admin_id?: string
          aid_record_id?: string
          created_at?: string
          id?: string
          new_status?: Database["public"]["Enums"]["report_status"] | null
          notes?: string | null
          previous_status?: Database["public"]["Enums"]["report_status"] | null
        }
        Relationships: [
          {
            foreignKeyName: "admin_action_logs_aid_record_id_fkey"
            columns: ["aid_record_id"]
            isOneToOne: false
            referencedRelation: "aid_records"
            referencedColumns: ["id"]
          },
        ]
      }
      aid_records: {
        Row: {
          aid_type: Database["public"]["Enums"]["aid_type"]
          approved_at: string | null
          approved_by: string | null
          area_id: string
          beneficiary_count: number | null
          created_at: string
          created_by: string | null
          delivery_date: string
          field_officer_name: string | null
          flag_reason: string | null
          flagged: boolean | null
          id: string
          is_duplicate_warning: boolean
          notes: string | null
          organization_id: string
          quantity: number
          rejection_reason: string | null
          status: Database["public"]["Enums"]["report_status"]
          unit: string
          updated_at: string
        }
        Insert: {
          aid_type: Database["public"]["Enums"]["aid_type"]
          approved_at?: string | null
          approved_by?: string | null
          area_id: string
          beneficiary_count?: number | null
          created_at?: string
          created_by?: string | null
          delivery_date: string
          field_officer_name?: string | null
          flag_reason?: string | null
          flagged?: boolean | null
          id?: string
          is_duplicate_warning?: boolean
          notes?: string | null
          organization_id: string
          quantity: number
          rejection_reason?: string | null
          status?: Database["public"]["Enums"]["report_status"]
          unit: string
          updated_at?: string
        }
        Update: {
          aid_type?: Database["public"]["Enums"]["aid_type"]
          approved_at?: string | null
          approved_by?: string | null
          area_id?: string
          beneficiary_count?: number | null
          created_at?: string
          created_by?: string | null
          delivery_date?: string
          field_officer_name?: string | null
          flag_reason?: string | null
          flagged?: boolean | null
          id?: string
          is_duplicate_warning?: boolean
          notes?: string | null
          organization_id?: string
          quantity?: number
          rejection_reason?: string | null
          status?: Database["public"]["Enums"]["report_status"]
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "aid_records_area_id_fkey"
            columns: ["area_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "aid_records_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      aid_restriction_rules: {
        Row: {
          aid_type: Database["public"]["Enums"]["aid_type"]
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          restriction_days: number
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          aid_type: Database["public"]["Enums"]["aid_type"]
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          restriction_days: number
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          aid_type?: Database["public"]["Enums"]["aid_type"]
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          restriction_days?: number
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      areas: {
        Row: {
          area_id: string
          country: string
          created_at: string
          district: string
          id: string
          latitude: number | null
          longitude: number | null
          population: number | null
          region: string
          status: Database["public"]["Enums"]["area_status"]
          updated_at: string
          village: string
        }
        Insert: {
          area_id: string
          country: string
          created_at?: string
          district: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          population?: number | null
          region: string
          status?: Database["public"]["Enums"]["area_status"]
          updated_at?: string
          village: string
        }
        Update: {
          area_id?: string
          country?: string
          created_at?: string
          district?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          population?: number | null
          region?: string
          status?: Database["public"]["Enums"]["area_status"]
          updated_at?: string
          village?: string
        }
        Relationships: []
      }
      duplicate_warnings: {
        Row: {
          acknowledged: boolean
          acknowledged_at: string | null
          acknowledged_by: string | null
          aid_record_id: string
          created_at: string
          id: string
          previous_record_id: string
          warning_reason: string
        }
        Insert: {
          acknowledged?: boolean
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          aid_record_id: string
          created_at?: string
          id?: string
          previous_record_id: string
          warning_reason: string
        }
        Update: {
          acknowledged?: boolean
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          aid_record_id?: string
          created_at?: string
          id?: string
          previous_record_id?: string
          warning_reason?: string
        }
        Relationships: [
          {
            foreignKeyName: "duplicate_warnings_aid_record_id_fkey"
            columns: ["aid_record_id"]
            isOneToOne: false
            referencedRelation: "aid_records"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "duplicate_warnings_previous_record_id_fkey"
            columns: ["previous_record_id"]
            isOneToOne: false
            referencedRelation: "aid_records"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          admin_notes: string | null
          created_at: string
          id: string
          is_read: boolean
          message: string
          related_record_id: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          admin_notes?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message: string
          related_record_id?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          admin_notes?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message?: string
          related_record_id?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_related_record_id_fkey"
            columns: ["related_record_id"]
            isOneToOne: false
            referencedRelation: "aid_records"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          contact_email: string | null
          contact_phone: string | null
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          email: string
          full_name: string | null
          id: string
          organization_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          email: string
          full_name?: string | null
          id?: string
          organization_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          email?: string
          full_name?: string | null
          id?: string
          organization_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      report_evidence: {
        Row: {
          aid_record_id: string
          created_at: string
          file_name: string
          file_type: string | null
          file_url: string
          id: string
          uploaded_by: string | null
        }
        Insert: {
          aid_record_id: string
          created_at?: string
          file_name: string
          file_type?: string | null
          file_url: string
          id?: string
          uploaded_by?: string | null
        }
        Update: {
          aid_record_id?: string
          created_at?: string
          file_name?: string
          file_type?: string | null
          file_url?: string
          id?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "report_evidence_aid_record_id_fkey"
            columns: ["aid_record_id"]
            isOneToOne: false
            referencedRelation: "aid_records"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      get_user_organization_id: { Args: { _user_id: string }; Returns: string }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      aid_type: "water" | "food" | "health" | "cash"
      app_role: "admin" | "ngo_user"
      area_status: "not_aided" | "partially_aided" | "fully_aided"
      report_status: "pending" | "approved" | "rejected" | "flagged"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      aid_type: ["water", "food", "health", "cash"],
      app_role: ["admin", "ngo_user"],
      area_status: ["not_aided", "partially_aided", "fully_aided"],
      report_status: ["pending", "approved", "rejected", "flagged"],
    },
  },
} as const
