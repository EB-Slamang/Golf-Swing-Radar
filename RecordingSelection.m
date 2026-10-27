% RECORDINGSELECTION - Choose the bundled WAV files to process.
% Each active fullfile line is RELATIVE to Pipeline/Datasets, not to your current
% MATLAB folder. Keep the cell-array braces and quote every folder/file component.
% Lines beginning with % are examples and are not processed. To change recordings,
% comment the current line and uncomment another existing path. Multiple active
% lines process a batch and produce one metrics row per recording.
%
% AvailableRecordings.csv lists every WAV actually included in this bundle.
% Some historical example paths are not included and are marked accordingly.
% Path spelling/case matters on Linux; use the names in that index. The originally
% selected P002/session1/Driver_FullSwing1.wav remains the default example.

%% Recording selection
% To process other recordings just uncomment them.
wavFile_CW_All = {
        

        %E.S Second Session Recordings
        %XONAR
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test1_3_5m.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test2_2m.wav')
        %Sound Blaster
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test3_3_5m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test4_2m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test5_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test6_2_5m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test7_3m_SoundBlaster_StraightArm.wav')

     % fullfile('P001', 'session2', '7Iron_FullSwing_Test1_2_5m_SoundBlaster.wav')
     % fullfile('P001', 'session2', '7Iron_FullSwing_Test2_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', '7Iron_FullSwing_Test3_2m_SoundBlaster.wav')

     % fullfile('P001', 'session2', 'Driver_FullSwing1_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing2_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing3_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing4_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing5_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing6_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing7_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing8_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing9_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing10_3m_SoundBlaster.wav')

        %E.S Third Session recordings
        %XONAR
            % Tests
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test1_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test2_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test3_3m_LineInput.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test4_2_5m_LineInput.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test5_2m_LineInput.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test6_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test7_3m_StraightArm.wav')
    % fullfile('P001', 'session3', 'Headless1.wav')
    
        %Dataset
    % fullfile('P001', 'session3', 'Driver_FullSwing1_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing2_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing3_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing4_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing5_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing6_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing7_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing8_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing9_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing10_3m.wav')

    % fullfile('P001', 'session3', '7Iron_FullSwing1_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing2_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing3_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing4_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing5_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing6_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing7_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing8_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing9_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing10_3m.wav')
    % 
    % fullfile('P001', 'session3', 'Wedge_FullSwing1_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing2_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing3_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing4_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing5_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing6_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing7_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing8_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing9_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing10_3m.wav')

        %J.M First Session Recordings
        %Tests
    % fullfile('P002', 'session1', 'Headless1.wav')
    % fullfile('P002', 'session1', 'Headless2.wav')
    % fullfile('P002', 'session1', 'Ball1.wav')
    % fullfile('P002', 'session1', 'Ball2.wav')
    % fullfile('P002', 'session1', 'Ball3.wav')
    % 
    %     Dataset
    fullfile('P002', 'session1', 'Driver_FullSwing1.wav')  
    % fullfile('P002', 'session1', 'Driver_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing5.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing6_stoponfollowthru.wav')
    % 
    % fullfile('P002', 'session1', 'Driver_BackSwing1.wav')
    % fullfile('P002', 'session1', 'Driver_BackSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Driver_Downswing1.wav')
    % fullfile('P002', 'session1', 'Driver_Downswing2.wav')

    % fullfile('P002', 'session1', '7Iron_Backswing1.wav')
    % fullfile('P002', 'session1', '7Iron_Backswing2.wav')
    % fullfile('P002', 'session1', '7Iron_Backswing3.wav')
    % 
    % fullfile('P002', 'session1', '7Iron_Downswing1.wav')
    % fullfile('P002', 'session1', '7Iron_Downswing2.wav')
    % fullfile('P002', 'session1', '7Iron_Downswing3.wav')
    % 
    % fullfile('P002', 'session1', '7Iron_Fullswing1_Slow.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing2.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing3.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing4.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing5.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing6_stoponfollowthru.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing7_stoponfollowthru.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_BackSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_BackSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_DownSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_DownSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_FullSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing5.wav')
  

        %J.M Second Session Recordings
        %Tests
    % fullfile('P002', 'session2', 'Practice.wav')
    % 
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m.wav')
    % 
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m_10deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m_10deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3m_10deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m_10deg_23cm.wav')
    % 
    %  fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m_15deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m_15deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3m_15deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m_15deg_23cm.wav')
    % % 
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m_15deg_41cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m_15deg_41cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3m_15deg_41cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m_15deg_41cm.wav')

    %     %Dataset
    % fullfile('P002', 'session2', 'Driver_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing2_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing3_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing4_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing5_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing6_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing7_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing8_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing9_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing10_3m.wav')
    % 
    % fullfile('P002', 'session2', '7Iron_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing2_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing3_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing4_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing5_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing6_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing7_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing8_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing9_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing10_3m.wav')
    % 
    % fullfile('P002', 'session2', 'Wedge_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing2_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing3_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing4_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing5_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing6_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing7_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing8_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing9_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing10_3m.wav')
    

    %Naasir
    %Xonar
    
    % fullfile('P003', 'session1', 'Practice.wav')

    % fullfile('P003', 'session1', 'Driver_Fullswing1_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing2_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing3_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing4_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing5_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing6_3_Slow.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing7_3_Slow.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing8_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing9_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing10_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing11_3.wav')
    % fullfile('P003', 'session1', 'Driver_Fullswing12_3.wav')
    % 
    % fullfile('P003', 'session1', '7Iron_Fullswing1_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing2_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing3_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing4_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing5_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing6_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing7_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing8_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing9_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing10_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing11_3m.wav')
    % fullfile('P003', 'session1', '7Iron_Fullswing12_3m_fast.wav')
    % 
    % fullfile('P003', 'session1', 'Wedge_Fullswing1_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing2_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing3_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing4_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing5_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing6_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing7_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing8_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing9_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing10_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing11_3m.wav')
    % fullfile('P003', 'session1', 'Wedge_Fullswing12_3m.wav')
    
     %Sloane
    %Xonar
        %Tests
    % fullfile('P004', 'session1', 'Practice.wav')
    % fullfile('P004', 'session1', 'Practice2_3_5m.wav')
    
        %Dataset
    % fullfile('P004', 'session1', 'Driver_FullSwing1_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing2_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing3_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing4_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing5_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing6_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing7_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing8_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing9_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing10_3m.wav')
    % fullfile('P004', 'session1', 'Driver_FullSwing11_3m.wav')
    % 
    % 
    % fullfile('P004', 'session1', '7Iron_FullSwing1_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing2_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing3_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing4_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing5_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing6_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing7_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing8_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing9_3m.wav')
    % fullfile('P004', 'session1', '7Iron_FullSwing10_3m.wav')
    % 
    % 
    % fullfile('P004', 'session1', 'Wedge_FullSwing1_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing2_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing3_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing4_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing5_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing6_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing7_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing8_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing9_3m.wav')
    % fullfile('P004', 'session1', 'Wedge_FullSwing10_3m.wav')


    
     
                    };
           


% Uncomment one or more filenames above before running the main script.
