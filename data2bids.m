function cfg = data2bids(cfg, varargin)

% DATA2BIDS is a helper function to convert MEG or anatomical MRI data to the Brain
% Imaging Data Structure. This function starts from an existing dataset on disk and
% creates the required sidecar files. The idea is that you write a script in which
% you call this function multiple times, once for each of the data files. For each
% data file it will write the corresponding JSON file. When operating on MEG data
% files, it will also write a corresponding channels.tsv and events.tsv file.
%
% Use as
%   data2bids(cfg)
% where cfg is a configuration structure that contains
%   cfg.dataset           = string, filename of the data on disk
%   cfg.anat.write        = string, 'yes' or 'no' (default = 'yes')
%   cfg.anat.dicomfile    = string, filename of a matching DICOM file
%   cfg.meg.write         = string, 'yes' or 'no' (default = 'yes')
%   cfg.channels.write    = string, 'yes' or 'no' (default = 'yes')
%   cfg.events.write      = string, 'yes' or 'no' (default = 'yes')
%   cfg.events.trl        = trial definition, see below
%
% You can specify cfg.events.trl as a Nx3 matrix with the trial definition (see
% FT_DEFINETRIAL) or as a MATLAB table. When specified as table, the first three
% columns containing integer values corresponding to the begsample, endsample and
% offset, the additional colums can be of another type and can have any name. If you
% do not specify the trial definition, the events will be read from the dataset and
% used.
%
% You can specify cfg.anat.dicomfile in combination with a NIFTI anatomical MRI. This
% will cause the detailled header information with MR scanner ans sequence details to
% be read from the DICOM file and used to fill in the details of the JSON file.
%
% General options that apply to all data types are
%   cfg.TaskName                    = string
%   cfg.InstitutionName             = string
%   cfg.InstitutionAddress          = string
%   cfg.InstitutionalDepartmentName = string
%   cfg.Manufacturer                = string
%   cfg.ManufacturersModelName      = string
%   cfg.DeviceSerialNumber          = string
%   cfg.SoftwareVersions            = string
%
% General options that apply to all functional data types are
%   cfg.TaskDescription             = string
%   cfg.Instructions                = string
%   cfg.CogAtlasID                  = string
%   cfg.CogPOID                     = string
%
% There are many more datatype specific options for the JSON files than can be listed
% here. Please open this function in the MATLAB editor to see what those are.
%
% Example use with a CTF dataset
%   cfg = []
%   cfg.dataset                     = 'sub-01_ses-meg_task-language_meg.ds';
%   cfg.TaskName                    = 'language';
%   cfg.meg.PowerLineFrequency      = 50;
%   cfg.InstitutionName             = 'Radboud University';
%   cfg.InstitutionalDepartmentName = 'Donders Institute for Brain, Cognition and Behaviour';
%   data2bids(cfg)
%
% Example use with an anatomical MRI
%   cfg = []
%   cfg.dataset                     = 'sub-01_ses-mri_T1w.nii';
%   cfg.anat.dicomfile              = '00080_1.3.12.2.1107.5.2.43.66068.2017082413175824865636649.IMA'
%   cfg.anat.MagneticFieldStrength  = 3;
%   cfg.InstitutionName             = 'Radboud University';
%   cfg.InstitutionalDepartmentName = 'Donders Institute for Brain, Cognition and Behaviour';
%   data2bids(cfg)
%
% This function corresponds to version 1.1.0 of the BIDS specification.
% See http://bids.neuroimaging.io/ for the details.

% Copyright (C) 2018, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% these are used by the ft_preamble/ft_postamble function and scripts
ft_revision = '$Id$';
ft_nargin   = nargin;
ft_nargout  = nargout;

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble debug

if ft_abort
  % do not continue function execution in case the outputfile is present and the user indicated to keep it
  return
end

% get the options and set the defaults
cfg.anat           = ft_getopt(cfg, 'anat');
cfg.anat.write     = ft_getopt(cfg.anat, 'write', 'yes');
cfg.anat.dicomfile = ft_getopt(cfg.anat, 'dicomfile');  % get the details from one of the original DICOM files

cfg.meg            = ft_getopt(cfg, 'meg');
cfg.meg.write      = ft_getopt(cfg.meg, 'write', 'yes');

cfg.channels       = ft_getopt(cfg, 'channels');
cfg.channels.write = ft_getopt(cfg.channels, 'write', 'yes');

cfg.events         = ft_getopt(cfg, 'events');
cfg.events.write   = ft_getopt(cfg.events, 'write', 'yes');
cfg.events.trl     = ft_getopt(cfg.events, 'trl');

%% Generic fields for all data types
cfg.TaskName                          = ft_getopt(cfg, 'TaskName'                    ); % REQUIRED. Name of the task (for resting state use the “rest” prefix). Different Tasks SHOULD NOT have the same name. The Task label is derived from this field by removing all non alphanumeric ([a-zA-Z0-9]) characters.
cfg.TaskDescription                   = ft_getopt(cfg, 'TaskDescription'             ); % OPTIONAL. Description of the task.
cfg.Instructions                      = ft_getopt(cfg, 'Instructions'                ); % OPTIONAL. Text of the instructions given to participants before the scan. This is not only important for behavioural or cognitive tasks but also in resting state paradigms (e.g. to distinguish between eyes open and eyes closed).
cfg.CogAtlasID                        = ft_getopt(cfg, 'CogAtlasID'                  ); % OPTIONAL. URL of the corresponding ​Cognitive Atlas term that describes the task (e.g. Resting State with eyes closed "​http://www.cognitiveatlas.org/term/id/trm_54e69c642d89b​"​)
cfg.CogPOID                           = ft_getopt(cfg, 'CogPOID'                     ); % OPTIONAL. URL of the corresponding ​CogPO term that describes the task (e.g. Rest “http://wiki.cogpo.org/index.php?title=Rest”)
cfg.Manufacturer                      = ft_getopt(cfg, 'Manufacturer'                ); % OPTIONAL. Manufacturer of the MEG system ("CTF", "​Elekta/Neuromag​", "​4D/BTi​", "​KIT/Yokogawa​", "​ITAB​", "KRISS", "Other")
cfg.ManufacturersModelName            = ft_getopt(cfg, 'ManufacturersModelName'      ); % OPTIONAL. Manufacturer’s designation of the MEG scanner model (e.g. "CTF-275"). See ​Appendix VII​ with preferred names
cfg.DeviceSerialNumber                = ft_getopt(cfg, 'DeviceSerialNumber'          ); % OPTIONAL. The serial number of the equipment that produced the composite instances. A pseudonym can also be used to prevent the equipment from being identifiable, as long as each pseudonym is unique within the dataset.
cfg.SoftwareVersions                  = ft_getopt(cfg, 'SoftwareVersions'            ); % OPTIONAL. Manufacturer’s designation of the acquisition software.
cfg.InstitutionName                   = ft_getopt(cfg, 'InstitutionName'             ); % OPTIONAL. The name of the institution in charge of the equipment that produced the composite instances.
cfg.InstitutionAddress                = ft_getopt(cfg, 'InstitutionAddress'          ); % OPTIONAL. The address of the institution in charge of the equipment that produced the composite instances.
cfg.InstitutionalDepartmentName       = ft_getopt(cfg, 'InstitutionalDepartmentName' ); % The department in the institution in charge of the equipment that produced the composite instances. Corresponds to DICOM Tag 0008, 1040 ”Institutional Department Name”.

%% MEG specific fields
cfg.meg.SamplingFrequency             = ft_getopt(cfg.meg, 'SamplingFrequency'           ); % REQUIRED. Sampling frequency (in Hz) of all the data in the recording, regardless of their type (e.g., 2400)
cfg.meg.PowerLineFrequency            = ft_getopt(cfg.meg, 'PowerLineFrequency'          ); % REQUIRED. Frequency (in Hz) of the power grid at the geographical location of the MEG instrument (i.e. 50 or 60)
cfg.meg.DewarPosition                 = ft_getopt(cfg.meg, 'DewarPosition'               ); % REQUIRED. Position of the dewar during the MEG scan: "upright", "supine" or "degrees" of angle from vertical: for example on CTF systems, upright=15°, supine = 90°.
cfg.meg.SoftwareFilters               = ft_getopt(cfg.meg, 'SoftwareFilters'             ); % REQUIRED. List of temporal and/or spatial software filters applied, orideally key:valuepairsofpre-appliedsoftwarefiltersandtheir parameter values: e.g., {"SSS": {"frame": "head", "badlimit": 7}}, {"SpatialCompensation": {"GradientOrder": Order of the gradient compensation}}. Write “n/a” if no software filters applied.
cfg.meg.DigitizedLandmarks            = ft_getopt(cfg.meg, 'DigitizedLandmarks'          ); % REQUIRED. Boolean (“true” or “false”) value indicating whether anatomical landmark points (i.e. fiducials) are contained within this recording.
cfg.meg.DigitizedHeadPoints           = ft_getopt(cfg.meg, 'DigitizedHeadPoints'         ); % REQUIRED. Boolean (“true” or “false”) value indicating whether head points outlining the scalp/face surface are contained within this recording.
cfg.meg.MEGChannelCount               = ft_getopt(cfg.meg, 'MEGChannelCount'             ); % OPTIONAL. Number of MEG channels (e.g. 275)
cfg.meg.MEGREFChannelCount            = ft_getopt(cfg.meg, 'MEGREFChannelCount'          ); % OPTIONAL. Number of MEG reference channels (e.g. 23). For systems without such channels (e.g. Neuromag Vectorview), MEGREFChannelCount​=0
cfg.meg.EEGChannelCount               = ft_getopt(cfg.meg, 'EEGChannelCount'             ); % OPTIONAL. Number of EEG channels recorded simultaneously (e.g. 21)
cfg.meg.ECOGChannelCount              = ft_getopt(cfg.meg, 'ECOGChannelCount'            ); % OPTIONAL. Number of ECoG channels
cfg.meg.SEEGChannelCount              = ft_getopt(cfg.meg, 'SEEGChannelCount'            ); % OPTIONAL. Number of SEEG channels
cfg.meg.EOGChannelCount               = ft_getopt(cfg.meg, 'EOGChannelCount'             ); % OPTIONAL. Number of EOG channels
cfg.meg.ECGChannelCount               = ft_getopt(cfg.meg, 'ECGChannelCount'             ); % OPTIONAL. Number of ECG channels
cfg.meg.EMGChannelCount               = ft_getopt(cfg.meg, 'EMGChannelCount'             ); % OPTIONAL. Number of EMG channels
cfg.meg.MiscChannelCount              = ft_getopt(cfg.meg, 'MiscChannelCount'            ); % OPTIONAL. Number of miscellaneous analog channels for auxiliary signals
cfg.meg.TriggerChannelCount           = ft_getopt(cfg.meg, 'TriggerChannelCount'         ); % OPTIONAL. Number of channels for digital (TTL bit level) triggers
cfg.meg.RecordingDuration             = ft_getopt(cfg.meg, 'RecordingDuration'           ); % OPTIONAL. Length of the recording in seconds (e.g. 3600)
cfg.meg.RecordingType                 = ft_getopt(cfg.meg, 'RecordingType'               ); % OPTIONAL. Defines whether the recording is “continuous” or “epoched”; this latter limited to time windows about events of interest (e.g., stimulus presentations, subject responses etc.)
cfg.meg.EpochLength                   = ft_getopt(cfg.meg, 'EpochLength'                 ); % OPTIONAL. Duration of individual epochs in seconds (e.g. 1) in case of epoched data
cfg.meg.ContinuousHeadLocalization    = ft_getopt(cfg.meg, 'ContinuousHeadLocalization'  ); % OPTIONAL. Boolean (“true” or “false”) value indicating whether continuous head localisation was performed.
cfg.meg.HeadCoilFrequency             = ft_getopt(cfg.meg, 'HeadCoilFrequency'           ); % OPTIONAL. List of frequencies (in Hz) used by the head localisation coils (‘HLC’ in CTF systems, ‘HPI’ in Elekta, ‘COH’ in 4D/BTi) that track the subject’s head position in the MEG helmet (e.g. [293, 307, 314, 321])
cfg.meg.MaxMovement                   = ft_getopt(cfg.meg, 'MaxMovement'                 ); % OPTIONAL. Maximum head movement (in mm) detected during the recording, as measured by the head localisation coils (e.g., 4.8)
cfg.meg.SubjectArtefactDescription    = ft_getopt(cfg.meg, 'SubjectArtefactDescription'  ); % OPTIONAL. Freeform description of the observed subject artefact and its possible cause (e.g. "Vagus Nerve Stimulator", “non-removable implant”). If this field is set to “n/a”, it will be interpreted as absence of major source of artifacts except cardiac and blinks.
cfg.meg.AssociatedEmptyRoom           = ft_getopt(cfg.meg, 'AssociatedEmptyRoom'         ); % OPTIONAL. Relative path in BIDS folder structure to empty-room file associated with the subject’s MEG recording. The path needs to use forward slashes instead of backward slashes (e.g. "sub-emptyroom/ses-<label>/meg/sub-emptyroom_ses-<label>_ta sk-noise_run-<label>_meg.ds").

%% Scanner Hardware
cfg.anat.MagneticFieldStrength         = ft_getopt(cfg.anat, 'MagneticFieldStrength'          ); % Nominal field strength of MR magnet in Tesla. Corresponds to DICOM Tag 0018,0087 “Magnetic Field Strength” .
cfg.anat.StationName                   = ft_getopt(cfg.anat, 'StationName'                    ); % Institution defined name of the machine that produced the composite instances. Corresponds to DICOM Tag 0008, 1010 “Station Name”
cfg.anat.HardcopyDeviceSoftwareVersion = ft_getopt(cfg.anat, 'HardcopyDeviceSoftwareVersion'  ); % (Deprecated) Manufacturer’s designation of the software of the device that created this Hardcopy Image (the printer). Corresponds to DICOM Tag 0018, 101A “Hardcopy Device Software Version”.
cfg.anat.ReceiveCoilName               = ft_getopt(cfg.anat, 'ReceiveCoilName'                ); % Information describing the receiver coil. Corresponds to DICOM Tag 0018, 1250 “Receive Coil Name”, although not all vendors populate that DICOM Tag, in which case this field can be derived from an appropriate private DICOM field.
cfg.anat.ReceiveCoilActiveElements     = ft_getopt(cfg.anat, 'ReceiveCoilActiveElements'      ); % Information describing the active/selected elements of the receiver coil.  This doesn’t correspond to a tag in the DICOM ontology. The vendor-defined terminology for active coil elements can go in this field. As an example, for Siemens, coil channels are typically not activated/selected individually, but rather  in pre-defined selectable “groups” of individual channels, and the list of the  “groups” of elements that are active/selected in any given scan populates  the “Coil String” entry in Siemen’s private DICOM fields (e.g., “HEA;HEP” for the Siemens standard 32 ch coil when both the anterior and posterior groups are activated). This is a flexible field that can be used as most appropriate for a given vendor and coil to define the “active” coil elements. Since individual scans can sometimes not have the intended coil elements selected, it is preferable for this field to be populated directly from the DICOM for each individual scan, so that it can be used as a mechanism for checking that a given scan was collected with the intended coil elements selected.
cfg.anat.GradientSetType               = ft_getopt(cfg.anat, 'GradientSetType'                ); % It should be possible to infer the gradient coil from the scanner model. If not,e.g. because of a custom upgrade or use of a gradient insert set, then the specifications of the actual gradient coil should be reported independently.
cfg.anat.MRTransmitCoilSequence        = ft_getopt(cfg.anat, 'MRTransmitCoilSequence'         ); % This is a relevant field if a non-standard transmit coil is used. Corresponds to DICOM Tag 0018, 9049 “MR Transmit Coil Sequence”.
cfg.anat.MatrixCoilMode                = ft_getopt(cfg.anat, 'MatrixCoilMode'                 ); % (If used) A method for reducing the number of independent channels by combining in analog the signals from multiple coil elements. There are typically different default modes when using un-accelerated or accelerated (e.g. GRAPPA, SENSE) imaging.
cfg.anat.CoilCombinationMethod         = ft_getopt(cfg.anat, 'CoilCombinationMethod'          ); % Almost all fMRI studies using phased-array coils use root-sum-of-squares (rSOS) combination, but other methods exist. The image reconstruction is changed by the coil combination method (as for the matrix coil mode above), so anything non-standard should be reported.

%% Sequence Specifics
cfg.anat.PulseSequenceType             = ft_getopt(cfg.anat, 'PulseSequenceType'              ); % A general description of the pulse sequence used for the scan (i.e. MPRAGE, Gradient Echo EPI, Spin Echo EPI, Multiband gradient echo EPI).
cfg.anat.ScanningSequence              = ft_getopt(cfg.anat, 'ScanningSequence'               ); % Description of the type of data acquired. Corresponds to DICOM Tag 0018, 0020 “Sequence Sequence”.
cfg.anat.SequenceVariant               = ft_getopt(cfg.anat, 'SequenceVariant'                ); % Variant of the ScanningSequence. Corresponds to DICOM Tag 0018, 0021 “Sequence Variant”.
cfg.anat.ScanOptions                   = ft_getopt(cfg.anat, 'ScanOptions'                    ); % Parameters of ScanningSequence. Corresponds to DICOM Tag 0018, 0022 “Scan Options”.
cfg.anat.SequenceName                  = ft_getopt(cfg.anat, 'SequenceName'                   ); % Manufacturer’s designation of the sequence name. Corresponds to DICOM Tag 0018, 0024 “Sequence Name”.
cfg.anat.PulseSequenceDetails          = ft_getopt(cfg.anat, 'PulseSequenceDetails'           ); % Information beyond pulse sequence type that identifies the specific pulse sequence used (i.e. "Standard Siemens Sequence distributed with the VB17 software,” “Siemens WIP ### version #.##,” or “Sequence written by X using a version compiled on MM/DD/YYYY”).
cfg.anat.NonlinearGradientCorrection   = ft_getopt(cfg.anat, 'NonlinearGradientCorrection'    ); % Boolean stating if the image saved  has been corrected for gradient nonlinearities by the scanner sequence.

%% In-Plane Spatial Encoding
cfg.anat.NumberShots                   = ft_getopt(cfg.anat, 'NumberShots'                    ); % The number of RF excitations need to reconstruct a slice or volume. Please mind that  this is not the same as Echo Train Length which denotes the number of lines of k-space collected after an excitation.
cfg.anat.ParallelReductionFactorInPlan = ft_getopt(cfg.anat, 'ParallelReductionFactorInPlane' ); % The parallel imaging (e.g, GRAPPA) factor. Use the denominator of the fraction of k-space encoded for each slice. For example, 2 means half of k-space is encoded. Corresponds to DICOM Tag 0018, 9069 “Parallel Reduction Factor In-plane”.
cfg.anat.ParallelAcquisitionTechnique  = ft_getopt(cfg.anat, 'ParallelAcquisitionTechnique'   ); % The type of parallel imaging used (e.g. GRAPPA, SENSE). Corresponds to DICOM Tag 0018, 9078 “Parallel Acquisition Technique”.
cfg.anat.PartialFourier                = ft_getopt(cfg.anat, 'PartialFourier'                 ); % The fraction of partial Fourier information collected. Corresponds to DICOM Tag 0018, 9081 ”Partial Fourier”.
cfg.anat.PartialFourierDirection       = ft_getopt(cfg.anat, 'PartialFourierDirection'        ); % The direction where only partial Fourier information was collected. Corresponds to DICOM Tag 0018, 9036 “Partial Fourier Direction”.
cfg.anat.PhaseEncodingDirection        = ft_getopt(cfg.anat, 'PhaseEncodingDirection'         ); % Possible values = [];                     % “i”, “j”, “k”, “i-”, “j-”, “k-”. The letters “i”, “j”, “k” correspond to the first, second and third axis of the data in the NIFTI file. The polarity of the phase encoding is assumed to go from zero index to maximum index unless ‘-’ sign is present (then the order is reversed - starting from the highest index instead of zero). PhaseEncodingDirection is defined as the direction along which phase is was modulated which may result in visible distortions. Note that this is not the same as the DICOM term InPlanePhaseEncodingDirection which can have “ROW” or “COL” values. This parameter is REQUIRED if corresponding fieldmap data is present or when using multiple runs with different phase encoding directions (which can be later used for field inhomogeneity correction).
cfg.anat.EffectiveEchoSpacing          = ft_getopt(cfg.anat, 'EffectiveEchoSpacing'           ); % The “effective” sampling interval, specified in seconds, between lines in the phase-encoding direction, defined based on the size of the reconstructed image in the phase direction.  It is frequently, but incorrectly, referred to as  “dwell time” (see DwellTime parameter below for actual dwell time).  It is  required for unwarping distortions using field maps. Note that beyond just in-plane acceleration, a variety of other manipulations to the phase encoding need to be accounted for properly, including partial fourier, phase oversampling, phase resolution, phase field-of-view and interpolation. This parameter is REQUIRED if corresponding fieldmap data is present.
cfg.anat.TotalReadoutTime              = ft_getopt(cfg.anat, 'TotalReadoutTime'               ); % This is actually the “effective” total readout time , defined as the readout duration, specified in seconds, that would have generated data with the given level of distortion.  It is NOT the actual, physical duration of the readout train.  If EffectiveEchoSpacing has been properly computed, it is just EffectiveEchoSpacing * (ReconMatrixPE - 1). . This parameter is REQUIRED if corresponding “field/distortion” maps acquired with opposing phase encoding directions are present  (see 8.9.4).
cfg.anat.WaterFatShift                 = ft_getopt(cfg.anat, 'WaterFatShift'                  ); % in pixels, is defined as the displacement of the water signal with respect to fat signal in the image. Water-fat shift (WFS) is expressed in number of pixels (e.g. 3 pixels). The WFS is directly related to the bandwidth per pixel in readout direction, and also to the effective echo spacing.
cfg.anat.EchoTrainLength               = ft_getopt(cfg.anat, 'EchoTrainLength'                ); % number of EPI echoes to acquire one slice. In Siemens, this parameter is the “EPI Factor”. Number of lines in k-space acquired per excitation per image.  Corresponds to In GE scanners it corresponds to the DICOM tag (0018,0091) for GE and Siemens; . In Philips, it corresponds to the tag (0019,10d9) for Philips.

%% Timing Parameters
cfg.anat.EchoTime                      = ft_getopt(cfg.anat, 'EchoTime'                       ); % The echo time (TE) for the acquisition, specified in seconds. This parameter is REQUIRED if corresponding fieldmap data is present or the data comes from a multi echo sequence. Corresponds to DICOM Tag 0018, 0081 “Echo Time”  (please note that the DICOM term is in milliseconds not seconds).
cfg.anat.InversionTime                 = ft_getopt(cfg.anat, 'InversionTime'                  ); % The inversion time (TI) for the acquisition, specified in seconds. Inversion time is the time after the middle of inverting RF pulse to middle of excitation pulse to detect the amount of longitudinal magnetization. Corresponds to DICOM Tag 0018, 0082 “Inversion Time”  (please note that the DICOM term is in milliseconds not seconds).
cfg.anat.SliceTiming                   = ft_getopt(cfg.anat, 'SliceTiming'                    ); % The time at which each slice was acquired within each volume (frame) of  the acquisition.  Slice timing is not slice order -- rather, it  is a list of times (in JSON format) containing the time (in seconds) of each slice acquisition in relation to the beginning of volume acquisition.  The list goes through the slices along the slice axis in the slice encoding dimension (see below). Note that to ensure the proper interpretation of the SliceTiming field, it is important to check if the (optional) SliceEncodingDirection exists. In particular,  if SliceEncodingDirection is negative, the entries in SliceTiming are defined in reverse order with respect to the slice axis (i.e., the final entry in the SliceTiming list is the time of acquisition of slice 0). This parameter is REQUIRED for sparse sequences that do not have the DelayTime field set. In addition without this parameter slice time correction will not be possible.
cfg.anat.SliceEncodingDirection        = ft_getopt(cfg.anat, 'SliceEncodingDirection'         ); % Possible values = [];                     % “i”, “j”, “k”, “i-”, “j-”, “k-” (the axis of the NIfTI data along which slices were acquired, and the direction in which SliceTiming is  defined with respect to). "i", "j", "k" identifiers correspond to the first, second and third axis of the data in the NIfTI file. A ‘-’ sign indicates that the contents of SliceTiming are defined in reverse order -- that is, the first entry corresponds to the slice with the largest index, and the final entry corresponds to slice index zero. When present ,the axis defined by SliceEncodingDirection  needs to be consistent with the ‘slice_dim’ field in the NIfTI header. When absent, the entries in SliceTiming must be in the order of increasing slice index as defined by the NIfTI header.
cfg.anat.DwellTime                     = ft_getopt(cfg.anat, 'DwellTime'                      ); %  Actual dwell time (in seconds) of the receiver per point in the readout direction, including any oversampling.  For Siemens, this corresponds to DICOM field (0019,1018) (in ns).   This value is necessary for the (optional) readout distortion correction of anatomicals in the HCP Pipelines.  It also usefully provides a handle on the readout bandwidth, which isn’t captured in the other metadata tags.  Not to be confused with “EffectiveEchoSpacing”, and the frequent mislabeling of echo spacing (which is spacing in the phase encoding direction) as “dwell time” (which is spacing in the readout direction).

%% RF & Contrast
cfg.anat.FlipAngle                     = ft_getopt(cfg.anat, 'FlipAngle'                      ); % Flip angle for the acquisition, specified in degrees. Corresponds to = [];                     % DICOM Tag 0018, 1314 “Flip Angle”.

%% Slice Acceleration
cfg.anat.MultibandAccelerationFactor   = ft_getopt(cfg.anat, 'MultibandAccelerationFactor'    ); % The multiband factor, for multiband acquisitions.

%% Anatomical landmarks, useful for multimodaltimodal co-registration with MEG, (S)EEG, TMS,etc
cfg.anat.AnatomicalLandmarkCoordinates = ft_getopt(cfg.anat, 'AnatomicalLandmarkCoordinates'  ); % Key:value pairs of any number of additional anatomical landmarks and their coordinates in voxel units (where first voxel has index 0,0,0) relative to the associated anatomical MRI, (e.g. {"AC" = []; % [127,119,149], "PC" = []; % [128,93,141], "IH" = []; % [131,114,206]}, or {"NAS" = []; % [127,213,139], "LPA" = []; % [52,113,96], "RPA" = []; % [202,113,91]}).

%% columns in the channels.tsv
cfg.channels.name               = ft_getopt(cfg.channels, 'name'               , nan);  % REQUIRED. Channel name (e.g., MRT012, MEG023)
cfg.channels.type               = ft_getopt(cfg.channels, 'type'               , nan);  % REQUIRED. Type of channel; MUST use the channel types listed below.
cfg.channels.units              = ft_getopt(cfg.channels, 'units'              , nan);  % REQUIRED. Physical unit of the data values recorded by this channel in SI (see Appendix V: Units for allowed symbols).
cfg.channels.description        = ft_getopt(cfg.channels, 'description'        , nan);  % OPTIONAL. Brief free-text description of the channel, or other information of interest. See examples below.
cfg.channels.sampling_frequency = ft_getopt(cfg.channels, 'sampling_frequency' , nan);  % OPTIONAL. Sampling rate of the channel in Hz.
cfg.channels.low_cutoff         = ft_getopt(cfg.channels, 'low_cutoff'         , nan);  % OPTIONAL. Frequencies used for the high-pass filter applied to the channel in Hz. If no high-pass filter applied, use n/a.
cfg.channels.high_cutoff        = ft_getopt(cfg.channels, 'high_cutoff'        , nan);  % OPTIONAL. Frequencies used for the low-pass filter applied to the channel in Hz. If no low-pass filter applied, use n/a. Note that hardware anti-aliasing in A/D conversion of all MEG/EEG electronics applies a low-pass filter; specify its frequency here if applicable.
cfg.channels.notch              = ft_getopt(cfg.channels, 'notch'              , nan);  % OPTIONAL. Frequencies used for the notch filter applied to the channel, in Hz. If no notch filter applied, use n/a.
cfg.channels.software_filters   = ft_getopt(cfg.channels, 'software_filters'   , nan);  % OPTIONAL. List of temporal and/or spatial software filters applied (e.g. "SSS", "SpatialCompensation"). Note that parameters should be defined in the general MEG sidecar .json file. Indicate n/a in the absence of software filters applied.
cfg.channels.status             = ft_getopt(cfg.channels, 'status'             , nan);  % OPTIONAL. Data quality observed on the channel (good/bad). A channel is considered bad if its data quality is compromised by excessive noise. Description of noise type SHOULD be provided in [status_description].
cfg.channels.status_description = ft_getopt(cfg.channels, 'status_description' , nan);  % OPTIONAL. Freeform text description of noise or artifact affecting data quality on the channel. It is meant to explain why the channel was declared bad in [status].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% read the information from the dataset
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% convert dataset to headerfile and datafile
cfg = ft_checkconfig(cfg, 'dataset2files', 'yes');
typ = ft_filetype(cfg.headerfile);

switch typ
  case {'nifti', 'nifti2'}
    mri = ft_read_mri(cfg.dataset);
    if ~isempty(cfg.anat.dicomfile)
      % read the header details from the dicom matching file that was specified by the user
      dcm = dicominfo(cfg.anat.dicomfile);
    else
      dcm = [];
    end
    
  otherwise
    hdr = ft_read_header(cfg.headerfile);
    evt = ft_read_event(cfg.datafile, 'header', hdr);
    
    fn = {'name' 'type' 'units' 'description' 'sampling_frequency' 'low_cutoff' 'high_cutoff' 'notch' 'software_filters' 'status' 'status_description'};
    for i=1:numel(fn)
      if numel(cfg.channels.(fn{i}))==1
        cfg.channels.(fn{i}) = repmat(cfg.channels.(fn{i}), hdr.nChans, 1);
      end
    end
end % switch typ

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% construct the json and tsv files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% start with empty metadata descriptions
anat_json    = [];
meg_json     = [];
events_tsv   = [];
channels_tsv = [];

switch typ
  case {'nifti', 'nifti2'}
    % make the relevant selection, all json fields start with a capital letter
    fn = fieldnames(cfg);
    fn = fn(~cellfun(@isempty, regexp(fn, '[A-Z].*')));
    generic_defaults = keepfields(cfg, fn);
    
    % make the relevant selection, all json fields start with a capital letter
    fn = fieldnames(cfg.meg);
    fn = fn(~cellfun(@isempty, regexp(fn, '[A-Z].*')));
    anat_defaults = keepfields(cfg.anat, fn);
    
    fn = fieldnames(cfg.anat);
    fn = fn(~cellfun(@isempty, regexp(fn, '[A-Z].*')));
    
    anat_json = keepfields(dcm, fn);
    anat_json = mergeconfig(anat_json, generic_defaults);
    anat_json = mergeconfig(anat_json, anat_defaults);
    
  case {'ctf_ds', 'ctf_meg4', 'ctf_res4'}
    % these MUST be present
    meg_json.SamplingFrequency          = hdr.Fs;
    
    % these SHOULD be present
    meg_json.MEGChannelCount            = sum(strcmp(hdr.chantype, 'megmag') | strcmp(hdr.chantype, 'meggrad') | strcmp(hdr.chantype, 'megplanar'));
    meg_json.MEGREFChannelCount         = sum(strcmp(hdr.chantype, 'refmag') | strcmp(hdr.chantype, 'refgrad'));
    meg_json.EEGChannelCount            = sum(strcmp(hdr.chantype, 'eeg'));
    meg_json.ECOGChannelCount           = sum(strcmp(hdr.chantype, '???'));
    meg_json.SEEGChannelCount           = sum(strcmp(hdr.chantype, '???'));
    meg_json.EOGChannelCount            = sum(strcmp(hdr.chantype, 'eog'));
    meg_json.ECGChannelCount            = sum(strcmp(hdr.chantype, 'ecg'));
    meg_json.EMGChannelCount            = sum(strcmp(hdr.chantype, 'emg'));
    meg_json.MiscChannelCount           = sum(strcmp(hdr.chantype, 'misc'));
    meg_json.TriggerChannelCount        = sum(strcmp(hdr.chantype, 'trigger'));
    meg_json.RecordingDuration          = (hdr.nTrials*hdr.nSamples)/hdr.Fs;
    meg_json.EpochLength                = hdr.nSamples/hdr.Fs;
    meg_json.ContinuousHeadLocalization = truefalse(any(isfield(hdr.chantype, 'headloc')));
    meg_json.Manufacturer               = 'CTF';
    meg_json.ManufacturersModelName     = upper(ft_senstype(hdr.grad));
    
    % make the relevant selection, all json fields start with a capital letter
    fn = fieldnames(cfg);
    fn = fn(~cellfun(@isempty, regexp(fn, '[A-Z].*')));
    generic_defaults = keepfields(cfg, fn);
    
    % make the relevant selection, all json fields start with a capital letter
    fn = fieldnames(cfg.meg);
    fn = fn(~cellfun(@isempty, regexp(fn, '[A-Z].*')));
    meg_defaults = keepfields(cfg.meg, fn);
    
    % merge the information from the defaults with the information obtained from the data
    meg_json = mergeconfig(meg_json, generic_defaults);
    meg_json = mergeconfig(meg_json, meg_defaults);
    
    % MEG data should also have a channels.tsv file
    name                = mergevector(hdr.label(:), cfg.channels.name);
    type                = mergevector(hdr.chantype(:), cfg.channels.type);
    units               = mergevector(hdr.chanunit(:), cfg.channels.units);
    sampling_frequency  = mergevector(repmat(hdr.Fs, hdr.nChans, 1), cfg.channels.sampling_frequency);
    % construct a table with the corresponding columns
    channels_tsv = table(name, type, units, sampling_frequency);
    
    % MEG data should also have an events.tsv file
    if istable(cfg.events.trl)
      % check that the column names are valid
      assert(stcmp(cfg.events.trl.Properties.VariableNames{1}, 'begsample'));
      assert(stcmp(cfg.events.trl.Properties.VariableNames{2}, 'endsample'));
      assert(stcmp(cfg.events.trl.Properties.VariableNames{3}, 'offset'));
      % use the events table as it is
      events_tsv = cfg.events.trl;
    elseif ~isempty(cfg.events.trl)
      % convert the trl matrix to an events table
      begsample = cfg.events.trl(:,1);
      endsample = cfg.events.trl(:,2);
      offset    = cfg.events.trl(:,3); % FIXME this is not used
      if any(offset~=0)
        ft_warning('the offset in the trl matrix is ignored');
      end
      if size(trl,2)>3
        ft_warning('additional columns in the trl matrix are ignored');
      end
      % convert to the required fields
      onset     = (begsample-1)/hdr.Fs;
      duration  = (endsample-begsample+1)/hdr.Fs;
      events_tsv = table(onset, duration);
    else
      % convert the events from the dataset into a table
      events_tsv = event2table(hdr, evt);
    end
    
  otherwise
    ft_error('not yet implemented for "%s"', typ);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% write the metadata to the json and tsv files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~isempty(anat_json) && istrue(cfg.anat.write)
  [p, f, x] = fileparts(cfg.dataset);
  filename = fullfile(p, [f '.json']);
  try
    existing = read_json(filename);
  catch
    existing = [];
  end
  write_json(filename, mergeconfig(existing, anat_json))
end

if ~isempty(meg_json) && istrue(cfg.meg.write)
  [p, f, x] = fileparts(cfg.dataset);
  filename = fullfile(p, [f '.json']);
  try
    existing = read_json(filename);
  catch
    existing = [];
  end
  write_json(filename, mergeconfig(existing, meg_json))
end

if ~isempty(channels_tsv) && istrue(cfg.channels.write)
  [p, f, x] = fileparts(cfg.dataset);
  filename = fullfile(p, [f '_channels.tsv']);
  try
    existing = read_tsv(filename);
  catch
    existing = [];
  end % try
  if ~isempty(existing)
    ft_error('existing file is not empty');
  end
  write_tsv(filename, channels_tsv);
end

if ~isempty(events_tsv) && istrue(cfg.events.write)
  [p, f, x] = fileparts(cfg.dataset);
  filename = fullfile(p, [f '_events.tsv']);
  try
    existing = read_tsv(filename);
  catch
    existing = [];
  end % try
  if ~isempty(existing)
    ft_error('existing file is not empty');
  end
  write_tsv(filename, events_tsv);
end

% do not return an output variable if not requested
if nargout
  clear cfg
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION convert event structure into table
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tab = event2table(hdr, evt)
if isempty(evt)
  tab = [];
else
  for i=1:numel(evt)
    % normalize missing values
    if isempty(evt(i).sample)
      evt(i).sample = nan;
    end
    if isempty(evt(i).duration)
      evt(i).duration = nan;
    end
    if isempty(evt(i).value)
      evt(i).value = nan;
    end
  end
  onset       = num2cell(([evt.sample]-1)/hdr.Fs)';   % in seconds
  duration    = num2cell([evt.duration]/hdr.Fs)';     % in seconds
  sample      = num2cell([evt.sample])';              % in samples, the first sample of the file is 1
  event_type  = {evt.type}';
  event_value = {evt.value}';
  tab = table(onset, duration, sample, event_type, event_value);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tsv = read_tsv(filename)
ft_info('reading %s\n', filename);
tsv = readtable(filename, 'Delimiter', 'tab', 'FileType', 'text', 'ReadVariableNames', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function write_tsv(filename, tsv)
ft_info('writing %s\n', filename);
writetable(tsv, filename, 'Delimiter', 'tab', 'FileType', 'text');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function json = read_json(filename)
ft_info('reading %s\n', filename);
if ft_hastoolbox('jsonlab', 3)
  json = loadjson(filename);
else
  fid = fopen(filename, 'r');
  str = fread(fid, [1 inf], 'char=>char');
  fclose(fid);
  json = jsondecode(str);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function write_json(filename, json)
json = remove_empty(json);
ft_info('writing %s\n', filename);
if ft_hastoolbox('jsonlab', 3)
  savejson('', json, filename);
else
  str = jsonencode(json);
  fid = fopen(filename, 'w');
  fwrite(fid, str);
  fclose(fid);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = truefalse(bool)
if bool
  str = 'true';
else
  str = 'false';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function s = remove_empty(s)
fn = fieldnames(s);
fn = fn(structfun(@isempty, s));
s = removefields(s, fn);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function x = mergevector(x, y)
assert(isequal(size(x), size(y)));
for i=1:numel(x)
  if isnumeric(x) && isnumeric(y) && isnan(x(i)) && ~isnan(y(i))
    x(i) = y(i);
  end
  if iscell(x) && iscell(y) && isempty(x{i}) && ~isempty(y{i})
    x{i} = y{i};
  end
  if iscell(x) && isnumeric(y) && isempty(x{i}) && ~isnan(y{i})
    x{i} = y(i);
  end
end
