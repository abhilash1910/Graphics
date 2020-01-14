




using System;
using System.Linq;
using Data.Util;
using UnityEditor.Graphing;
using UnityEditor.ShaderGraph.Drawing;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Serialization;
using UnityEditor.Graphing.Util;
using UnityEngine.UIElements;

namespace UnityEditor.Rendering.HighDefinition
{
    partial class StackLitMasterNode : IVersionable<StackLitMasterNode.Version>
    {
        enum Version
        {
            InitialVersion = 0,
            UseDecalLayerMask = 1,
        }
        [SerializeField] Version m_Version;
        Version IVersionable<Version>.version
        {
            get => m_Version;
            set => m_Version = value;
        }
        static readonly MigrationDescription<Version, StackLitMasterNode> k_Migrations = new MigrationDescription<Version, StackLitMasterNode>(
            new MigrationStep<Version, StackLitMasterNode>(Version.InitialVersion, Migrations.InitialVersion),
            new MigrationStep<Version, StackLitMasterNode>(Version.UseDecalLayerMask, Migrations.UseDecalLayerMask)
        );
    }


    partial class StackLitMasterNode
    {
        #region Fields
        [SerializeField] DecalLayerMask m_DecalLayerMask = DecalLayerMask.Full;
        public DecalLayerMask decalLayerMask
        {
            get => m_DecalLayerMask;
            set
            {
                if (m_DecalLayerMask == value) return;
        
                m_DecalLayerMask = value;
                Dirty(ModificationScope.Graph);
            }
        }
        #endregion
        #region Migration
        [FormerlySerializedAs("m_ReceiveDecals")]
        [SerializeField]
        [Obsolete("Since 8.0.0, use m_DecalLayerMask instead.")]
        bool m_ObsoleteReceiveDecals = true;
        
        static partial class Migrations
        {
        #pragma warning disable 618
            public static void UseDecalLayerMask(StackLitMasterNode instance)
            {
                instance.m_DecalLayerMask = instance.m_ObsoleteReceiveDecals
                    ? DecalLayerMask.Full
                    : DecalLayerMask.None;
            }
        #pragma warning restore 618
        }
        #endregion
    }

    partial class StackLitSubShader
    {
        static void SetDecalLayerMaskActiveFields(StackLitMasterNode masterNode, ActiveFields.Base baseActiveFields)
        {
            if (masterNode.decalLayerMask == DecalLayerMask.None)
            {
                baseActiveFields.AddAll("DisableDecals");
            }
        }
    }
}

namespace UnityEditor.Rendering.HighDefinition.Drawing
{
    partial class StackLitSettingsView
    {
        void AddDecalLayerMaskField(PropertySheet ps, int indentLevel)
        {
            ps.Add(new PropertyRow(CreateLabel("Decal Layer Mask", indentLevel)), (row) =>
            {
                row.Add(new MaskField(
                    DecalLayerMask.LayerNames.ToList(),
                    (int)DecalLayerMask.Full,
                    null),
                    field =>
                    {
                        field.value = (int) m_Node.decalLayerMask;
                        field.RegisterValueChangedCallback(ChangeDecalLayerMask);
                    });
            });
        }
        
        void ChangeDecalLayerMask(ChangeEvent<int> evt)
        {
            m_Node.owner.owner.RegisterCompleteObjectUndo("Decal Layer Mask Change");
            m_Node.decalLayerMask = (DecalLayerMask)evt.newValue;
        }
    }
}
